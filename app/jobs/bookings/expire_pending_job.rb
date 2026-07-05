# frozen_string_literal: true

module Bookings
  class ExpirePendingJob < ApplicationJob
    queue_as :default

    def perform
      Booking.pending_payment
             .where(payment_expires_at: ...Time.current)
             .find_each do |booking|
               booking.update!(status: :cancelled)
             end
    end
  end
end
