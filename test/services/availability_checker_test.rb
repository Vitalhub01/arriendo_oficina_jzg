# frozen_string_literal: true

require 'test_helper'

class AvailabilityCheckerTest < ActiveSupport::TestCase
  setup do
    @box = boxes(:published_box)
    @checker = AvailabilityChecker.new(@box)
    @slot = next_monday_at(hour: 10)
  end

  test 'available within rules' do
    assert @checker.available?(@slot, @slot + 2.hours)
  end

  test 'blocked during availability block' do
    @box.availability_blocks.create!(
      start_at: @slot,
      end_at: @slot + 4.hours,
      reason: 'Test'
    )

    assert_not @checker.available?(@slot, @slot + 2.hours)
    assert_equal 'Horario bloqueado', @checker.error_message
  end

  test 'ignores expired pending bookings' do
    Booking.create!(
      box: @box,
      renter: users(:renter),
      start_at: @slot,
      end_at: @slot + 2.hours,
      hours: 2,
      total_amount_cents: @box.price_for_duration(2),
      status: :pending_payment,
      payment_expires_at: 1.minute.ago
    )

    assert @checker.available?(@slot, @slot + 2.hours)
  end
end
