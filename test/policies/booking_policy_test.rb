# frozen_string_literal: true

require 'test_helper'

class BookingPolicyTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      space: boxes(:published_box),
      profesional: users(:renter),
      start_at: 2.days.from_now.change(hour: 10),
      end_at: 2.days.from_now.change(hour: 12),
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

  test 'owner can cancel booking on their box' do
    policy = BookingPolicy.new(users(:owner), @booking)
    assert policy.cancel?
  end
end
