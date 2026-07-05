# frozen_string_literal: true

require 'test_helper'

module Bookings
  class ExpirePendingJobTest < ActiveSupport::TestCase
    setup do
      @box = boxes(:published_box)
      @renter = users(:renter)
      @slot_time = next_monday_at(hour: 10)
    end

    test 'cancels expired pending bookings and frees slot' do
      booking = Booking.create!(
        box: @box,
        renter: @renter,
        start_at: @slot_time,
        end_at: @slot_time + 2.hours,
        hours: 2,
        total_amount_cents: @box.price_for_duration(2),
        status: :pending_payment,
        payment_expires_at: 1.minute.ago
      )

      Bookings::ExpirePendingJob.perform_now

      assert booking.reload.cancelled?
      checker = AvailabilityChecker.new(@box)
      assert checker.available?(@slot_time, @slot_time + 2.hours)
    end
  end
end
