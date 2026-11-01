# frozen_string_literal: true

require 'test_helper'

class BookingsVerifyPaymentSlotTest < ActiveSupport::TestCase
  setup do
    @box = boxes(:published_box)
    @slot_time = next_monday_at(hour: 10)
    @renter = users(:renter)
  end

  test 'allows checkout when booking holds a free slot' do
    booking = pending_booking_for(@renter)

    result = Bookings::VerifyPaymentSlot.new(booking: booking).call

    assert result.success?
  end

  test 'rejects when payment window expired' do
    booking = pending_booking_for(@renter, payment_expires_at: 1.minute.ago)

    result = Bookings::VerifyPaymentSlot.new(booking: booking).call

    assert_not result.success?
    assert_includes result.errors.join(' '), 'plazo'
  end

  private

  def pending_booking_for(user, payment_expires_at: 30.minutes.from_now)
    Booking.create!(
      space: @box,
      profesional: user,
      start_at: @slot_time,
      end_at: @slot_time + 2.hours,
      hours: 2,
      duration_minutes: 120,
      total_amount_cents: @box.default_price_per_slot_cents * 2,
      status: :pending_payment,
      payment_expires_at: payment_expires_at,
      booking_type: :slot_based
    )
  end
end
