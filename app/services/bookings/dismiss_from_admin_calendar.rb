# frozen_string_literal: true

module Bookings
  class DismissFromAdminCalendar
    HIDDEN_KEY = 'admin_calendar_hidden'

    def initialize(booking:, actor:)
      @booking = booking
      @actor = actor
    end

    def call
      return failure('No tienes permiso') unless @actor.admin?
      return failure('Solo aplica a reservas anuladas') unless @booking.cancelled?

      breakdown = @booking.pricing_breakdown.merge(HIDDEN_KEY => true)
      @booking.update!(pricing_breakdown: breakdown)
      Result.new(success: true)
    end

    def self.hidden?(booking)
      booking.pricing_breakdown[HIDDEN_KEY] == true
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
