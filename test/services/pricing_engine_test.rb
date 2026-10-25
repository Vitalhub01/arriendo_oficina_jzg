# frozen_string_literal: true

require 'test_helper'

class PricingEngineTest < ActiveSupport::TestCase
  setup do
    @space = boxes(:published_box)
    @user = users(:renter)
    @start_at = next_monday_at(hour: 10)
  end

  test 'calculates price from schedule blocks' do
    result = PricingEngine.calculate(@space, @user, @start_at, 2, end_at: @start_at + 2.hours)

    assert_equal 30_000, result[:subtotal_cents]
  end

  test 'uses block-specific prices' do
    @space.schedule_blocks.for_day(0).where(start_time: Time.zone.parse('2000-01-01 10:00:00')).update_all(price_cents: 10_000)

    result = PricingEngine.calculate(@space, @user, @start_at, 1, end_at: @start_at + 1.hour)

    assert_equal 10_000, result[:subtotal_cents]
  end

  test 'adds optional equipment rental per hour' do
    item = equipment_items(:wifi_equipment)
    item.update_columns(price_per_hour_cents: 500)

    result = PricingEngine.calculate(
      @space, @user, @start_at, 2, end_at: @start_at + 2.hours, rented_equipment_items: [item]
    )

    assert_equal 31_000, result[:subtotal_cents]
    assert_equal 31_000, result[:total_cents]
    equipment_line = result[:breakdown].find { |line| line[:type] == 'equipment_rental' }
    assert_equal 1000, equipment_line[:amount_cents]
  end

  test 'ignores equipment rental when none selected' do
    result = PricingEngine.calculate(@space, @user, @start_at, 2, end_at: @start_at + 2.hours, rented_equipment_items: [])

    assert_equal 30_000, result[:subtotal_cents]
  end

  test 'jornada booking uses flat jornada price not sum of hourly blocks' do
    jornada = @space.primary_jornada_definition
    start_at = Time.zone.local(@start_at.year, @start_at.month, @start_at.day, 8, 0)
    end_at = Time.zone.local(@start_at.year, @start_at.month, @start_at.day, 20, 0)

    result = PricingEngine.calculate(
      @space,
      @user,
      start_at,
      @space.schedule_block_count_for_interval(start_at, end_at),
      end_at: end_at,
      booking_type: :jornada,
      jornada_definition: jornada
    )

    assert_equal jornada.price_cents, result[:subtotal_cents]
    assert_equal jornada.price_cents, result[:total_cents]
  end

  test 'applies per-space volume discount' do
    @space.pricing_rules.create!(
      name: 'Volumen test',
      rule_type: :volume_discount,
      config: { 'min_slots' => 2, 'discount_percent' => 10 },
      active: true,
      priority: 10
    )

    result = PricingEngine.calculate(@space, @user, @start_at, 2, end_at: @start_at + 2.hours)

    assert_equal 30_000, result[:subtotal_cents]
    assert_equal 3000, result[:discount_cents]
  end
end
