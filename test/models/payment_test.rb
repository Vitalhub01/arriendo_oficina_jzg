# frozen_string_literal: true

require 'test_helper'

class PaymentTest < ActiveSupport::TestCase
  test 'spot offer payment does not require booking' do
    admin = users(:admin)
    profesional = users(:profesional)
    offer = SpotOffer.create!(
      space: boxes(:published_box),
      created_by: admin,
      profesional: profesional,
      total_price_cents: 100_000,
      starts_on: Date.current,
      ends_on: Date.current + 7.days,
      daily_start_time: Time.zone.parse('08:00'),
      daily_end_time: Time.zone.parse('14:00')
    )

    payment = Payment.create!(
      spot_offer: offer,
      payer: profesional,
      payment_kind: :spot_offer,
      amount_cents: offer.total_price_cents,
      status: :pending
    )

    assert_nil payment.booking_id
    assert_equal offer.id, payment.spot_offer_id
  end
end
