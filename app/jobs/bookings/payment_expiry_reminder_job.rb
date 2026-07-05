# frozen_string_literal: true

module Bookings
  class PaymentExpiryReminderJob < ApplicationJob
    queue_as :mailers

    def perform
      window_start = 15.minutes.from_now
      window_end = 30.minutes.from_now

      Booking.pending_payment
             .where(payment_expires_at: window_start..window_end)
             .find_each do |booking|
               BookingMailer.payment_expiring_soon(booking).deliver_later
             end
    end
  end
end
