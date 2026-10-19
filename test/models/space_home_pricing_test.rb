# frozen_string_literal: true

require 'test_helper'

class SpaceHomePricingTest < ActiveSupport::TestCase
  test 'home_min_flexible_block_price_cents uses slot rate prices when present' do
    space = boxes(:published_box)
    space.slot_rates.create!(
      name: 'Mañana',
      start_time: Time.zone.parse('2000-01-01 08:00'),
      end_time: Time.zone.parse('2000-01-01 13:00'),
      price_per_slot_cents: 3_000,
      block_price_cents: 25_000,
      position: 0
    )

    assert_equal 3_000, Space.home_min_flexible_block_price_cents
  end

  test 'home_min_jornada_price_cents uses active jornadas on published spaces' do
    space = boxes(:published_box)
    JornadaDefinition.create!(
      space: space,
      office: space.office,
      name: 'Jornada completa',
      start_time: Time.zone.parse('2000-01-01 08:00'),
      end_time: Time.zone.parse('2000-01-01 20:00'),
      price_cents: 80_000,
      active: true,
      position: 0
    )

    assert_equal 80_000, Space.home_min_jornada_price_cents
  end
end
