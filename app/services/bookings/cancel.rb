# frozen_string_literal: true

module Bookings
  class Cancel
    def initialize(booking:, actor:)
      @booking = booking
      @actor = actor
    end

    def call
      return failure('No se puede cancelar esta reserva') unless cancellable?

      @booking.update!(status: :cancelled)
      Payments::MercadoPago::RefundJob.perform_later(@booking.payment.id) if @booking.payment&.approved?
      BookingMailer.booking_cancelled(@booking).deliver_later
      Result.new(success: true)
    end

    def cancellable?
      return true if @actor.admin?
      return false unless @booking.profesional_id == @actor.id
      return false if @booking.completed? || @booking.cancelled? || @booking.rescheduled?

      @booking.pending_payment? || (@booking.confirmed? && @booking.start_at > Time.current)
    end

    private

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
