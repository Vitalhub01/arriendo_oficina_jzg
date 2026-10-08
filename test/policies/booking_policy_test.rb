# frozen_string_literal: true

require 'test_helper'

class BookingPolicyTest < ActiveSupport::TestCase
  include IntegrationHelpers

  setup do
    start_at = next_monday_at(hour: 10)
    @booking = Booking.create!(
      space: boxes(:published_box),
      profesional: users(:renter),
      start_at: start_at,
      end_at: start_at + 2.hours,
      hours: 2,
      duration_minutes: 120,
      total_amount_cents: boxes(:published_box).default_price_per_slot_cents * 2,
      status: :pending_payment,
      payment_expires_at: 30.minutes.from_now,
      booking_type: :slot_based
    )
  end

  test 'renter can cancel pending payment booking' do
    policy = BookingPolicy.new(users(:renter), @booking)
    assert policy.cancel?
  end

  test 'admin can cancel booking' do
    policy = BookingPolicy.new(users(:admin), @booking)
    assert policy.cancel?
  end
end
