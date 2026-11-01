# frozen_string_literal: true

require 'test_helper'

class AdminSpotOffersTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
  end

  test 'index loads for admin' do
    sign_in @admin
    get admin_spot_offers_path
    assert_response :success
  end

  test 'show loads by share token in url' do
    sign_in @admin
    offer = SpotOffer.create!(
      space: boxes(:published_box),
      created_by: @admin,
      total_price_cents: 50_000,
      starts_on: Date.current,
      ends_on: Date.current + 7.days,
      daily_start_time: Time.zone.parse('08:00'),
      daily_end_time: Time.zone.parse('14:00')
    )

    get admin_spot_offer_path(offer)

    assert_response :success
    assert_match offer.token, response.body
  end
end
