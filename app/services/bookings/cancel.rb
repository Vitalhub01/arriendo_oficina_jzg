# frozen_string_literal: true

module Bookings
  class Cancel
    def initialize(booking:, actor:)
      @booking = booking
      @actor = actor
    end

    def call
      return failure('No se puede cancelar esta reserva') unless cancellable?

      release_discount_code_redemption!
      @booking.update!(status: :cancelled)
      Payments::MercadoPago::RefundJob.perform_later(@booking.payment.id) if @booking.payment&.approved?
      BookingMailer.booking_cancelled(@booking).deliver_later
      Result.new(success: true)
    end

    def cancellable?
      return true if @actor.admin?
      return false unless @booking.profesional_id == @actor.id
      return false if @booking.completed? || @booking.cancelled? || @booking.rescheduled?

      @booking.pending_payment?
    end

    private

    def release_discount_code_redemption!
      code = @booking.discount_code
      return unless code

      code.release_redemption!
    end

    def failure(message)
      Result.new(success: false, errors: [message])
    end

    class Result
      attr_reader :errors

      def initialize(success:, errors: [])
        @success = success
        @errors = errors
      end

      def success?
        @success
      end
    end
  end
end
