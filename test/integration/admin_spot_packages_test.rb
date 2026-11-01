# frozen_string_literal: true

require 'test_helper'

class AdminSpotPackagesTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @profesional = users(:profesional)
    @offer = SpotOffer.create!(
      space: boxes(:published_box),
      created_by: @admin,
      profesional: @profesional,
      total_price_cents: 80_000,
      starts_on: Date.current,
      ends_on: Date.current + 7.days,
      daily_start_time: Time.zone.parse('08:00'),
      daily_end_time: Time.zone.parse('14:00'),
      occurrence_count: 1
    )
    start_at = 2.days.from_now.change(hour: 10)
    @spot_booking = @offer.bookings.create!(
      space: boxes(:published_box),
      profesional: @profesional,
      start_at: start_at,
      end_at: start_at + 2.hours,
      duration_minutes: 120,
      booking_type: :hourly,
      status: :pending_payment,
      total_amount_cents: 80_000,
      discount_cents: 0,
      pricing_breakdown: {}
    )
  end

  test 'spot packages index loads for admin' do
    sign_in @admin
    get admin_spot_packages_path
    assert_response :success
    assert_match @offer.space.title, response.body
  end

  test 'manual confirm from spot package page' do
    sign_in @admin
    patch admin_spot_package_path(@offer), params: { confirm_manually: true }
    assert_redirected_to admin_spot_package_path(@offer)
    assert @offer.reload.paid?
  end
end
