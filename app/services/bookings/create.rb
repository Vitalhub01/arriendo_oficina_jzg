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

      @space.with_lock do
        interval = ReservationInterval.new(space: @space, params: @params).resolve
        return Result.new(success: false, errors: interval.errors) unless interval.success?

        start_at = interval.start_at
        end_at = interval.end_at
        duration_minutes = ((end_at - start_at) / 60).to_i
        slot_count = availability_slot_count(start_at, end_at, duration_minutes)

        checker = AvailabilityChecker.new(@space)
        unless checker.consecutive_slots_available?(start_at, slot_count)
          message = checker.error_message || 'Horario no disponible'
          message = slot_unavailable_message(message)
          return Result.new(success: false, errors: [message])
        end

        booking = @space.bookings.build(
          profesional: @profesional,
          start_at: start_at,
          end_at: end_at,
          duration_minutes: duration_minutes,
          booking_type: interval.booking_type,
          jornada_definition: interval.jornada_definition,
          reschedule_credit: find_reschedule_credit,
          terms_accepted_at: (@space.terms_and_conditions.attached? ? Time.current : nil)
        )
        booking.reservation_slot_rate = interval.slot_rate
        booking.reservation_mode = interval.mode
        booking.rented_equipment_item_ids = @space.rented_equipment_items_from_params(@params).pluck(:id)

        if booking.save
          mark_credit_applied!(booking) if booking.reschedule_credit_id.present?
          auto_confirm_if_free!(booking)
          Result.new(success: true, booking: booking)
        else
          errors = booking.errors.full_messages.map { |message| slot_unavailable_message(message) }
          Result.new(success: false, booking: booking, errors: errors)
        end
      end
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message.include?('bookings_no_overlap')

      Result.new(success: false, errors: [VerifyPaymentSlot::CONFLICT_MESSAGE])
    end

    private

    def slot_unavailable_message(message)
      case message
      when 'Ya reservado', 'El horario seleccionado ya no está disponible'
        VerifyPaymentSlot::CONFLICT_MESSAGE
      else
        message
      end
    end

    def validate_terms_acceptance
      return if !@require_terms_acceptance || !@space.terms_and_conditions.attached?

      return if ActiveModel::Type::Boolean.new.cast(@params[:accept_terms])

      'Debes aceptar los términos y condiciones del espacio'
    end

    def availability_slot_count(start_at, end_at, duration_minutes)
      count = @space.schedule_block_count_for_interval(start_at, end_at)
      return count if count.positive?

      (duration_minutes.to_f / @space.slot_duration_minutes).ceil
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
