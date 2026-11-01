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

  test 'preview returns session count for admin' do
    sign_in @admin
    space = boxes(:published_box)
    starts_on = 1.week.from_now.to_date.beginning_of_week(:monday)
    ends_on = starts_on + 2.weeks

    post preview_admin_spot_offers_path, params: {
      spot_offer: {
        space_id: space.id,
        total_price_cents: 80_000,
        starts_on: starts_on,
        ends_on: ends_on,
        daily_start_time: '08:00',
        daily_end_time: '12:00',
        weekdays: [1, 3]
      }
    }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body['count'].is_a?(Integer)
    assert_includes body['weekdays_summary'], 'Jueves'
  end
end
