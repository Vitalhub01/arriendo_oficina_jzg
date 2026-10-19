# frozen_string_literal: true

module Bookings
  class Create
    def initialize(space:, profesional:, params:, require_terms_acceptance: true)
      @space = space
      @profesional = profesional
      @params = params
      @require_terms_acceptance = require_terms_acceptance
    end

    def call
      terms_error = validate_terms_acceptance
      return Result.new(success: false, errors: [terms_error]) if terms_error

      slot_count = resolve_slot_count
      start_at, end_at = parse_times(slot_count)
      duration_minutes = ((end_at - start_at) / 60).to_i

      booking = @space.bookings.build(
        profesional: @profesional,
        start_at: start_at,
        end_at: end_at,
        duration_minutes: duration_minutes,
        booking_type: :slot_based,
        reschedule_credit: find_reschedule_credit,
        terms_accepted_at: (@space.terms_and_conditions.attached? ? Time.current : nil)
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

    def validate_terms_acceptance
      return if !@require_terms_acceptance || !@space.terms_and_conditions.attached?

      return if ActiveModel::Type::Boolean.new.cast(@params[:accept_terms])

      'Debes aceptar los términos y condiciones del espacio'
    end

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

      blocks = ScheduleBlockResolver.consecutive_blocks_from(@space, start_at, slot_count)
      if blocks.any?
        end_at = blocks.last.ends_at_on(date)
        return [start_at, end_at]
      end

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
