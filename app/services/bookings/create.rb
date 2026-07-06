# frozen_string_literal: true

module Bookings
  class Create
    def initialize(space:, profesional:, params:)
      @space = space
      @profesional = profesional
      @params = params
    end

    def call
      slot_count = resolve_slot_count
      start_at, end_at = parse_times(slot_count)

      booking = @space.bookings.build(
        profesional: @profesional,
        start_at: start_at,
        end_at: end_at,
        duration_minutes: slot_count * @space.slot_duration_minutes,
        booking_type: :slot_based,
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

    def resolve_slot_count
      if @params[:slot_count].present?
        @params[:slot_count].to_i
      elsif @params[:hours].present?
        hours = @params[:hours].to_i
        slots = (hours * 60.0 / @space.slot_duration_minutes).ceil
        [slots, @space.minimum_slots].max
      else
        @space.minimum_slots
      end
    end

    def parse_times(slot_count)
      date = Date.parse(@params[:date].to_s)
      hour, min = @params[:start_time].to_s.split(':').map(&:to_i)
      start_at = Time.zone.local(date.year, date.month, date.day, hour, min)
      end_at = start_at + (slot_count * @space.slot_duration_minutes).minutes

      [start_at, end_at]
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
