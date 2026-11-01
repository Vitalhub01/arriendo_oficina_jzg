# frozen_string_literal: true

require 'test_helper'

class BookingReservationValueTest < ActiveSupport::TestCase
  setup do
    @box = boxes(:published_box)
    @renter = users(:renter)
    @start_at = next_monday_at(hour: 10)
    result = Bookings::Create.new(
      space: @box,
      profesional: @renter,
      params: {
        date: @start_at.to_date.to_s,
        start_time: @start_at.strftime('%H:%M'),
        slot_count: 2
      }
    ).call
    @booking = result.booking
  end

  test 'reservation_value uses subtotal when total zero after reschedule credit' do
    source = @booking
    @booking.update!(
      total_amount_cents: 0,
      pricing_breakdown: {
        'subtotal_cents' => 48_000,
        'reservation_mode' => 'jornada',
        'breakdown' => [{ 'type' => 'base', 'amount_cents' => 48_000 }]
      }
    )
    credit = RescheduleCredit.create!(
      user: @booking.profesional,
      source_booking: source,
      amount_cents: 48_000,
      hours: 12,
      status: :applied
    )
    @booking.update!(reschedule_credit: credit)

    assert_equal 48_000, @booking.reservation_value_cents
    assert_equal '$48.000', @booking.formatted_reservation_value
  end
end
