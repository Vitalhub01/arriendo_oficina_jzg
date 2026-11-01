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

  test 'pricing detail exposes base and equipment lines from breakdown' do
    item = equipment_items(:wifi_equipment)
    item.update_columns(price_per_hour_cents: 500)
    @booking.update!(
      total_amount_cents: 31_000,
      pricing_breakdown: {
        'subtotal_cents' => 31_000,
        'reservation_mode' => 'hora',
        'rented_equipment_item_ids' => [item.id],
        'breakdown' => [
          { 'type' => 'base', 'label' => '2 hora(s) (2h)', 'amount_cents' => 30_000 },
          { 'type' => 'equipment_rental', 'equipment_item_id' => item.id, 'label' => 'WiFi (2 hora(s))',
            'amount_cents' => 1000 }
        ]
      }
    )

    assert @booking.pricing_detail_visible?
    assert_equal 30_000, @booking.pricing_base_amount_cents
    assert_equal 1, @booking.pricing_equipment_lines.size
    assert_match(/500/, @booking.pricing_equipment_line_label(@booking.pricing_equipment_lines.first))
    assert_match 'Reserva por hora', @booking.pricing_base_label
  end
end
