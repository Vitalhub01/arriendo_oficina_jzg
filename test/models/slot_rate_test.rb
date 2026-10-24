# frozen_string_literal: true

require 'test_helper'

class SlotRateTest < ActiveSupport::TestCase
  setup do
    @space = boxes(:published_box)
    @rate = SlotRate.create!(
      space: @space,
      name: 'Mañana',
      start_time: Time.zone.parse('2000-01-01 08:00'),
      end_time: Time.zone.parse('2000-01-01 13:00'),
      price_per_slot_cents: 12_500,
      position: 0
    )
  end

  test 'covers time within range' do
    assert @rate.covers_time?(Time.zone.parse('2000-01-01 10:00'))
    assert_not @rate.covers_time?(Time.zone.parse('2000-01-01 14:00'))
  end

  test 'for_bloque_reservation excludes non period rates' do
    SlotRate.create!(
      space: @space,
      name: 'Jornada completa',
      start_time: Time.zone.parse('2000-01-01 08:00'),
      end_time: Time.zone.parse('2000-01-01 20:00'),
      price_per_slot_cents: 40_000,
      block_price_cents: 40_000,
      position: 2
    )

    names = @space.bloque_slot_rates.pluck(:name)
    assert_includes names, 'Mañana'
    assert_not_includes names, 'Jornada completa'
  end

  test 'validates end after start' do
    rate = SlotRate.new(
      space: @space,
      name: 'Invalid',
      start_time: Time.zone.parse('2000-01-01 14:00'),
      end_time: Time.zone.parse('2000-01-01 08:00'),
      price_per_slot_cents: 10_000
    )
    assert_not rate.valid?
  end
end
