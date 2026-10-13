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
