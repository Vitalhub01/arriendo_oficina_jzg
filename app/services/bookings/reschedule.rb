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
      return failure(modification_limit_message) if modification_limit_reached?
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
      requires_payment = false
      rollback_errors = nil

      ActiveRecord::Base.transaction do
        credit = create_credit!

        result = Bookings::Create.new(
          space: @booking.space,
          profesional: @booking.profesional,
          params: create_params.merge(
            slot_count: slot_count,
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
      return @booking.total_amount_cents if @booking.total_amount_cents.positive?

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

    def pending_reschedule_in_progress?
      RescheduleCredit
        .applied
        .where(source_booking_id: @booking.id)
        .joins(:applied_booking)
        .exists?(bookings: { status: Booking.statuses[:pending_payment] })
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
