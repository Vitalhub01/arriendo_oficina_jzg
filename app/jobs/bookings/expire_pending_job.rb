# frozen_string_literal: true

module Bookings
  class ExpirePendingJob < ApplicationJob
    queue_as :default

    def perform(booking_id = nil)
      if booking_id
        expire_booking(booking_id)
      else
        sweep_expired_pending
      end
    end

    private

    def expire_booking(booking_id)
      booking = Booking.find_by(id: booking_id)
      return unless booking&.pending_payment?
      return unless booking.payment_expires_at.present? && booking.payment_expires_at <= Time.current

      cancel_expired!(booking)
    end

    def sweep_expired_pending
      Booking.pending_payment
             .where(payment_expires_at: ...Time.current)
             .find_each { |booking| cancel_expired!(booking) }
    end

    def cancel_expired!(booking)
      ReleaseRescheduleAttempt.new(booking: booking).call
      booking.update!(status: :cancelled)
    end
  end
end
