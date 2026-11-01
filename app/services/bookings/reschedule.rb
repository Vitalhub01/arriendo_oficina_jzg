# frozen_string_literal: true

module Bookings
  class Reschedule
    MAX_MODIFICATIONS = 3

    def initialize(booking:, actor:, params:)
      @booking = booking
      @actor = actor
      @params = params
    end

    def call
      if @booking.spot_offer_id.present? && !@actor.admin?
        return failure('Las reservas de tarifa spot solo pueden reprogramarlas un administrador')
      end

      return failure(modification_limit_message) if modification_limit_reached?
      return failure('La reserva no puede reprogramarse') unless rescheduleable?
      return failure('Indica la nueva fecha y horario') if @params[:date].blank?

      interval = ReservationInterval.new(space: @booking.space, params: create_params).resolve
      return failure(interval.errors.join(', ')) unless interval.success?

      if same_schedule?(interval.start_at, interval.end_at)
        return failure('Elige una fecha y horario distintos a los de la reserva actual')
      end

      new_booking = nil
      requires_payment = false
      rollback_errors = nil

      ActiveRecord::Base.transaction do
        credit = create_credit!

        result = Bookings::Create.new(
          space: @booking.space,
          profesional: @booking.profesional,
          params: create_params.merge(
            reschedule_credit_id: credit.id
          ),
          require_terms_acceptance: false
        ).call

        unless result.success?
          rollback_errors = result.errors
          raise ActiveRecord::Rollback
        end

        new_booking = result.booking
        requires_payment = payment_required_to_complete?(new_booking)

        unless requires_payment
          Bookings::FinalizeReschedule.new(booking: new_booking).call
        end
      end

      if rollback_errors
        return failure(rollback_errors.join(', '))
      end

      if new_booking
        Result.new(success: true, booking: new_booking, requires_payment: requires_payment)
      else
        failure('No se pudo reprogramar la reserva')
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(', '))
    end

    def rescheduleable?
      return true if @actor.admin?
      return false if @booking.spot_offer_id.present?

      return false unless @booking.profesional_id == @actor.id
      return false if @booking.cancelled? || @booking.completed? || @booking.rescheduled? || @booking.pending_payment?
      return false if modification_limit_reached?
      return false if pending_reschedule_in_progress?

      @booking.confirmed? && @booking.start_at > reschedule_cutoff
    end

    def modification_limit_reached?
      return false if @actor.admin?

      @booking.reschedule_modifications_count >= MAX_MODIFICATIONS
    end

    def modification_limit_message
      'Has alcanzado el límite de modificaciones para esta reserva'
    end

    def credit_amount_cents
      face_value = reschedule_face_value_cents
      return face_value if face_value.positive?

      inherited = @booking.reschedule_credit&.amount_cents
      return inherited if inherited.to_i.positive?

      @booking.payment&.amount_cents.to_i
    end

    private

    def reschedule_cutoff
      notice_hours = @booking.space.reschedule_notice_hours
      if notice_hours.blank?
        notice_hours = SiteSetting.get('reschedule_notice_hours', ENV.fetch('RESCHEDULE_NOTICE_HOURS', '12')).to_i
      end
      notice_hours.to_i.hours.from_now
    end

    def create_credit!
      RescheduleCredit.create!(
        user: @booking.profesional,
        source_booking: @booking,
        amount_cents: credit_amount_cents,
        hours: @booking.hours.to_i,
        status: :available,
        expires_at: 6.months.from_now
      )
    end

    def create_params
      params = { date: @params[:date] }

      case reservation_mode
      when 'jornada'
        params.merge(reservation_mode: 'jornada')
      when 'bloque'
        slot_rate_id = effective_slot_rate_id
        return params unless slot_rate_id

        params.merge(reservation_mode: 'bloque', slot_rate_id: slot_rate_id)
      else
        params.merge(
          reservation_mode: 'hora',
          start_time: @params[:start_time],
          slot_count: resolve_slot_count
        )
      end
    end

    def reservation_mode
      @params[:reservation_mode].presence || @booking.reschedule_reservation_mode
    end

    def effective_slot_rate_id
      @params[:slot_rate_id].presence ||
        @booking.stored_slot_rate_id ||
        @booking.reschedule_slot_rate&.id
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

    def same_schedule?(new_start_at, new_end_at)
      new_start_at == @booking.start_at && new_end_at == @booking.end_at
    end

    def reschedule_face_value_cents
      subtotal = @booking.pricing_breakdown&.dig('subtotal_cents').to_i
      return subtotal if subtotal.positive?

      paid = @booking.total_amount_cents.to_i + @booking.promo_discount_cents.to_i
      return paid if paid.positive?

      0
    end

    def pending_reschedule_in_progress?
      @booking.pending_reschedule_replacement.present?
    end

    def payment_required_to_complete?(booking)
      booking.pending_payment? && booking.total_amount_cents.positive?
    end

    def failure(message)
      Result.new(success: false, errors: [message])
    end

    class Result
      attr_reader :booking, :errors

      def initialize(success:, booking: nil, errors: [], requires_payment: false)
        @success = success
        @booking = booking
        @errors = errors
        @requires_payment = requires_payment
      end

      def success?
        @success
      end

      def requires_payment?
        @requires_payment
      end
    end
  end
end
