# frozen_string_literal: true

require 'test_helper'

class SpaceHomePricingTest < ActiveSupport::TestCase
  setup do
    Rails.cache.delete('spaces/home_pricing_snapshot/v2')
  end

  test 'home_min_flexible_block_price_cents uses slot rate prices when present' do
    space = boxes(:published_box)
    space.slot_rates.find_by!(name: 'Mañana').update!(price_per_slot_cents: 3_000)

    assert_equal 3_000, Space.home_min_flexible_block_price_cents
  end

  test 'home block prices use mañana and tarde slot rate block prices' do
    space = boxes(:published_box)
    space.slot_rates.find_by!(name: 'Mañana').update!(block_price_cents: 25_000)
    space.slot_rates.find_by!(name: 'Tarde').update!(block_price_cents: 28_000)

    assert_equal 25_000, Space.home_min_morning_block_price_cents
    assert_equal 28_000, Space.home_min_afternoon_block_price_cents
  end

  test 'morning and afternoon hourly prices come from slot rates' do
    space = boxes(:published_box)
    space.slot_rates.find_by!(name: 'Mañana').update!(price_per_slot_cents: 7_000)
    space.slot_rates.find_by!(name: 'Tarde').update!(price_per_slot_cents: 8_500)

    assert_equal 7_000, space.morning_hourly_price_cents
    assert_equal 8_500, space.afternoon_hourly_price_cents
  end

  test 'home_min_jornada_price_cents uses active jornadas on published spaces' do
    space = boxes(:published_box)
    space.jornada_definitions.find_by!(name: 'Jornada completa').update!(price_cents: 80_000)

    assert_equal 80_000, Space.home_min_jornada_price_cents
  end
end
