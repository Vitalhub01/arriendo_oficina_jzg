# frozen_string_literal: true

module Bookings
  class RestoreCancelled
    def initialize(booking:, actor:)
      @booking = booking
      @actor = actor
    end

    def call
      return failure('No tienes permiso') unless @actor.admin?
      return failure('Solo se pueden reactivar reservas anuladas') unless @booking.cancelled?
      return failure('El horario ya no está disponible') if slot_taken?

      @booking.update!(status: :confirmed)
      Result.new(success: true)
    end

    private

    def slot_taken?
      @booking.space.bookings.blocking_availability
                  .where.not(id: @booking.id)
                  .exists?(['start_at < ? AND end_at > ?', @booking.end_at, @booking.start_at])
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
