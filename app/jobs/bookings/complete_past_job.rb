# frozen_string_literal: true

module Bookings
  class CompletePastJob < ApplicationJob
    queue_as :default

    def perform
      Booking.confirmed
             .where(end_at: ...Time.current)
             .find_each { |booking| booking.update!(status: :completed) }
    end
  end
end
