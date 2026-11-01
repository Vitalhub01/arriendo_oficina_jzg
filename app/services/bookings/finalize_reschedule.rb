# frozen_string_literal: true

module Bookings
  # Marks the source booking as rescheduled once the replacement booking is confirmed.
  class FinalizeReschedule
    def initialize(booking:)
      @booking = booking
    end

    def call
      credit = @booking.reschedule_credit
      return false unless credit&.applied?

      source = credit.source_booking
      return true if source.rescheduled?

      source.with_lock do
        source.reload
        if source.rescheduled?
          true
        else
          new_count = source.reschedule_modifications_count + 1
          source.update!(status: :rescheduled, reschedule_modifications_count: new_count)
          @booking.update!(reschedule_modifications_count: new_count)
          true
        end
      end

      true
    end
  end
end
