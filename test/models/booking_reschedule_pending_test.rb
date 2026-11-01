# frozen_string_literal: true

require 'test_helper'

class BookingReschedulePendingTest < ActiveSupport::TestCase
  setup do
    @box = boxes(:published_box)
    @renter = users(:renter)
    @start_at = next_monday_at(hour: 10)
    @booking = create_confirmed_booking!(@start_at, slot_count: 2)
  end

  test 'pending_reschedule_replacement returns pending payment replacement' do
    new_start = @start_at + 7.days
    result = reschedule!(@booking, new_start, slot_count: 3)
    replacement = result.booking

    assert_equal replacement, @booking.pending_reschedule_replacement
    assert replacement.reschedule_replacement?
    assert_equal @booking, replacement.reschedule_source_booking
  end

  private

  def create_confirmed_booking!(start_at, slot_count:)
    result = Bookings::Create.new(
      space: @box,
      profesional: @renter,
      params: {
        date: start_at.to_date.to_s,
        start_time: start_at.strftime('%H:%M'),
        slot_count: slot_count
      }
    ).call
    raise result.errors.inspect unless result.success?

    booking = result.booking
    booking.update!(status: :confirmed, payment_expires_at: nil)
    booking
  end

  def reschedule!(booking, new_start, slot_count:)
    Bookings::Reschedule.new(
      booking: booking,
      actor: @renter,
      params: {
        date: new_start.to_date.to_s,
        start_time: new_start.strftime('%H:%M'),
        slot_count: slot_count
      }
    ).call
  end
end
