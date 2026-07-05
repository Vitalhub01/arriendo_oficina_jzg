# frozen_string_literal: true

module Bookings
  class Create
    def initialize(space:, profesional:, params:)
      @space = space
      @profesional = profesional
      @params = params
    end

    def call
      booking_type = @params[:booking_type].to_s == 'jornada' ? :jornada : :hourly
      jornada_definition = find_jornada_definition if booking_type == :jornada
      start_at, end_at = parse_times(booking_type, jornada_definition)

      booking = @space.bookings.build(
        profesional: @profesional,
        start_at: start_at,
        end_at: end_at,
        booking_type: booking_type,
        jornada_definition: jornada_definition,
        reschedule_credit: find_reschedule_credit
      )

      if booking.save
        mark_credit_applied!(booking) if booking.reschedule_credit_id.present?
        auto_confirm_if_free!(booking)
        Result.new(success: true, booking: booking)
      else
        Result.new(success: false, booking: booking, errors: booking.errors.full_messages)
      end
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message.include?('bookings_no_overlap')

      Result.new(success: false, errors: ['El horario seleccionado ya no está disponible'])
    end

    private

    def find_jornada_definition
      JornadaDefinition.active.find(@params[:jornada_definition_id])
    end

    def parse_times(booking_type, jornada_definition)
      date = Date.parse(@params[:date].to_s)

      if booking_type == :jornada && jornada_definition
        start_at = combine_date_time(date, jornada_definition.start_time)
        end_at = combine_date_time(date, jornada_definition.end_time)
      else
        hour, min = @params[:start_time].to_s.split(':').map(&:to_i)
        start_at = Time.zone.local(date.year, date.month, date.day, hour, min)
        end_at = start_at + @params[:hours].to_i.hours
      end

      [start_at, end_at]
    end

    def combine_date_time(date, time)
      Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
    end

    def find_reschedule_credit
      return unless @params[:reschedule_credit_id].present?

      @profesional.reschedule_credits.usable.find(@params[:reschedule_credit_id])
    end

    def mark_credit_applied!(booking)
      credit = booking.reschedule_credit
      credit.update!(status: :applied, applied_booking: booking)
    end

    def auto_confirm_if_free!(booking)
      return unless booking.total_amount_cents.zero?

      booking.update!(status: :confirmed, payment_expires_at: nil)
    end

    class Result
      attr_reader :booking, :errors

      def initialize(success:, booking: nil, errors: [])
        @success = success
        @booking = booking
        @errors = errors
      end

      def success?
        @success
      end
    end
  end
end
