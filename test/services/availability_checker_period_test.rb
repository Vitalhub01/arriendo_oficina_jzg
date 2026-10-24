# frozen_string_literal: true

require 'test_helper'

class AvailabilityCheckerPeriodTest < ActiveSupport::TestCase
  setup do
    @space = boxes(:published_box)
    @checker = AvailabilityChecker.new(@space)
    @date = next_monday_at(hour: 10).to_date
    @morning = @space.slot_rates.create!(
      name: 'Mañana',
      start_time: Time.zone.parse('2000-01-01 08:00'),
      end_time: Time.zone.parse('2000-01-01 13:00'),
      price_per_slot_cents: 7_000,
      block_price_cents: 25_000,
      position: 0
    )
    @slot = Time.zone.local(@date.year, @date.month, @date.day, 10, 0)
  end

  test 'slot rate window unavailable when an hour inside is booked' do
    Booking.create!(
      space: @space,
      profesional: users(:renter),
      start_at: @slot,
      end_at: @slot + 2.hours,
      hours: 2,
      duration_minutes: 120,
      total_amount_cents: 14_000,
      status: :confirmed,
      booking_type: :slot_based
    )

    assert_not @checker.slot_rate_window_available?(@date, @morning)
    assert_equal AvailabilityChecker::PERIOD_BOOKING_BLOCKED_MESSAGE, @checker.error_message
  end

  test 'slot rate window available when no conflicts' do
    assert @checker.slot_rate_window_available?(@date, @morning)
  end
end
