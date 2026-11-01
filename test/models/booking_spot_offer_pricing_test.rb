# frozen_string_literal: true

require 'test_helper'

class BookingSpotOfferPricingTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @profesional = users(:profesional)
    @offer = SpotOffer.create!(
      space: boxes(:published_box),
      created_by: @admin,
      profesional: @profesional,
      total_price_cents: 100_000,
      starts_on: Date.current,
      ends_on: Date.current + 7.days,
      daily_start_time: Time.zone.parse('08:00'),
      daily_end_time: Time.zone.parse('14:00'),
      occurrence_count: 2,
      status: :paid
    )
    start_at = 2.days.from_now.change(hour: 10)
    @first = @offer.bookings.create!(
      space: boxes(:published_box),
      profesional: @profesional,
      start_at: start_at,
      end_at: start_at + 2.hours,
      duration_minutes: 120,
      booking_type: :hourly,
      status: :confirmed,
      total_amount_cents: 50_000,
      discount_cents: 0,
      pricing_breakdown: {}
    )
    @second = @offer.bookings.create!(
      space: boxes(:published_box),
      profesional: @profesional,
      start_at: start_at + 1.week,
      end_at: start_at + 1.week + 2.hours,
      duration_minutes: 120,
      booking_type: :hourly,
      status: :confirmed,
      total_amount_cents: 50_000,
      discount_cents: 0,
      pricing_breakdown: {}
    )
  end

  test 'spot package session index and badge label' do
    assert_equal 1, @first.spot_package_session_index
    assert_equal 2, @second.spot_package_session_index
    assert_equal 2, @first.spot_package_sessions_count

    label = ApplicationController.helpers.booking_spot_offer_price_badge_label(@second)
    assert_includes label, 'Reserva de tarifa particular'
    assert_includes label, "##{@second.id}"
    assert_includes label, @second.formatted_spot_package_total
    assert_includes label, '2/2 reservas'
  end
end
