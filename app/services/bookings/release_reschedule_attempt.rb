# frozen_string_literal: true

module Bookings
  # Reverts a pending reschedule when payment is abandoned or the replacement booking is cancelled.
  class ReleaseRescheduleAttempt
    def initialize(booking:)
      @booking = booking
    end

    def call
      credit = @booking.reschedule_credit
      return unless credit&.applied?

      source = credit.source_booking
      return if source.nil? || source.rescheduled?

      ApplicationRecord.transaction do
        @booking.update!(reschedule_credit_id: nil)
        credit.destroy!
      end
    end
  end
end
