# frozen_string_literal: true

module Bookings
  # Confirms the booking still holds the slot before redirecting to Mercado Pago.
  class VerifyPaymentSlot
    CONFLICT_MESSAGE =
      'Ese horario ya no está disponible: otra persona está completando el pago.'.freeze
    EXPIRED_MESSAGE =
      'Tu plazo para pagar esta reserva expiró. Vuelve a elegir fecha y horario.'.freeze

    def initialize(booking:)
      @booking = booking
    end

    def call
      return failure(EXPIRED_MESSAGE) if @booking.payment_expired?
      return failure('Esta reserva ya no está pendiente de pago') unless @booking.pending_payment?

      if foreign_blocking_bookings.exists?
        return failure(CONFLICT_MESSAGE)
      end

      checker = AvailabilityChecker.new(@booking.space)
      unless checker.available?(@booking.start_at, @booking.end_at, exclude_booking: @booking)
        message = checker.error_message == 'Ya reservado' ? CONFLICT_MESSAGE : checker.error_message
        return failure(message)
      end

      Result.new(success: true)
    end

    private

    def foreign_blocking_bookings
      @booking.space.bookings.blocking_availability
                 .where('start_at < ? AND end_at > ?', @booking.end_at, @booking.start_at)
                 .where.not(id: @booking.id)
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
