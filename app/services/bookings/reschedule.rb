# frozen_string_literal: true

module Bookings
  class Reschedule
    def initialize(booking:, actor:, params:)
      @booking = booking
      @actor = actor
      @params = params
    end

    def call
      return failure('La reserva no puede reprogramarse') unless rescheduleable?
      return failure('Indica la nueva fecha y horario') if @params[:date].blank?

      new_start_at = parse_start_at
      slot_count = resolve_slot_count
      new_end_at = new_start_at + (slot_count * @booking.space.slot_duration_minutes).minutes

      checker = AvailabilityChecker.new(@booking.space)
      unless checker.consecutive_slots_available?(new_start_at, slot_count)
        return failure(checker.error_message || 'Horario no disponible')
      end

      new_booking = nil
      ActiveRecord::Base.transaction do
        credit = create_credit!
        @booking.update!(status: :rescheduled)

        result = Bookings::Create.new(
          space: @booking.space,
          profesional: @booking.profesional,
          params: create_params.merge(
            slot_count: slot_count,
            reschedule_credit_id: credit.id
          )
        ).call

        unless result.success?
          raise ActiveRecord::Rollback, result.errors.join(', ')
        end

        new_booking = result.booking
      end

      if new_booking
        Result.new(success: true, booking: new_booking)
      else
        failure('No se pudo reprogramar la reserva')
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(', '))
    end

    def rescheduleable?
      return true if @actor.admin?
      return false unless @booking.profesional_id == @actor.id
      return false if @booking.cancelled? || @booking.completed? || @booking.rescheduled? || @booking.pending_payment?

      @booking.confirmed? && @booking.start_at > reschedule_cutoff
    end

    private

    def reschedule_cutoff
      notice_hours = SiteSetting.get('reschedule_notice_hours', ENV.fetch('RESCHEDULE_NOTICE_HOURS', '24')).to_i
      notice_hours.hours.from_now
    end

    def create_credit!
      RescheduleCredit.create!(
        user: @booking.profesional,
        source_booking: @booking,
        amount_cents: @booking.total_amount_cents,
        hours: @booking.hours.to_i,
        status: :available,
        expires_at: 6.months.from_now
      )
    end

    def create_params
      {
        date: @params[:date],
        start_time: @params[:start_time],
        slot_count: resolve_slot_count
      }
    end

    def resolve_slot_count
      if @params[:slot_count].present?
        @params[:slot_count].to_i
      elsif @params[:hours].present?
        (@params[:hours].to_i * 60.0 / @booking.space.slot_duration_minutes).ceil
      else
        @booking.slot_count
      end
    end

    def parse_start_at
      date = Date.parse(@params[:date].to_s)
      hour, min = @params[:start_time].to_s.split(':').map(&:to_i)
      Time.zone.local(date.year, date.month, date.day, hour, min)
    end

    def failure(message)
      Result.new(success: false, errors: [message])
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
