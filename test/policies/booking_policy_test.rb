# frozen_string_literal: true

require 'test_helper'

class BookingPolicyTest < ActiveSupport::TestCase
  setup do
    @booking = Booking.create!(
      box: boxes(:published_box),
      renter: users(:renter),
      start_at: 2.days.from_now.change(hour: 10),
      end_at: 2.days.from_now.change(hour: 12),
      hours: 2,
      total_amount_cents: boxes(:published_box).price_for_duration(2),
      status: :pending_payment,
      payment_expires_at: 30.minutes.from_now
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
