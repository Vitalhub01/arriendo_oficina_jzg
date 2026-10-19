# frozen_string_literal: true

module Bookings
  class ConfirmManually
    def initialize(booking:, actor:)
      @booking = booking
      @actor = actor
    end

    def call
      return failure('Solo un administrador puede confirmar manualmente') unless @actor.admin?
      return failure('La reserva no está pendiente de pago') unless @booking.pending_payment?
      return failure('El plazo de pago ya venció') if @booking.payment_expired?

      @booking.update!(
        status: :confirmed,
        payment_expires_at: nil,
        manually_confirmed_at: Time.current
      )
      BookingMailer.booking_confirmed(@booking).deliver_later
      Result.new(success: true)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.join(', '))
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
