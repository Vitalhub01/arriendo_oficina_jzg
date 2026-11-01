# frozen_string_literal: true

require 'test_helper'

class SpotOffersConfirmManuallyTest < ActiveSupport::TestCase
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
      occurrence_count: 2
    )
    @start = 2.days.from_now.change(hour: 10)
    2.times do |i|
      @offer.bookings.create!(
        space: boxes(:published_box),
        profesional: @profesional,
        start_at: @start + i.weeks,
        end_at: @start + i.weeks + 2.hours,
        duration_minutes: 120,
        booking_type: :hourly,
        status: :pending_payment,
        total_amount_cents: 50_000,
        discount_cents: 0,
        pricing_breakdown: {}
      )
    end
  end

  test 'confirms all pending bookings and marks offer paid' do
    result = SpotOffers::ConfirmManually.new(spot_offer: @offer, actor: @admin).call

    assert result.success?
    assert @offer.reload.paid?
    assert @offer.bookings.all?(&:confirmed?)
    assert @offer.payment.approved?
  end

  test 'rejects partial confirmation when one booking is already confirmed' do
    @offer.bookings.first.update!(status: :confirmed, payment_expires_at: nil)

    result = SpotOffers::ConfirmManually.new(spot_offer: @offer, actor: @admin).call

    assert_not result.success?
    assert_includes result.errors.join, 'paquete completo'
  end
end
