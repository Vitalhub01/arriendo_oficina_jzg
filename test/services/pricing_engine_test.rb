# frozen_string_literal: true

require 'test_helper'

class PricingEngineTest < ActiveSupport::TestCase
  setup do
    @space = boxes(:published_box)
    @user = users(:renter)
    @start_at = next_monday_at(hour: 10)
  end

  test 'calculates default price per slot' do
    result = PricingEngine.calculate(@space, @user, @start_at, 2)

    assert_equal @space.default_price_per_slot_cents * 2, result[:subtotal_cents]
  end

  test 'uses slot rate for time period' do
    SlotRate.create!(
      space: @space,
      name: 'Mañana',
      start_time: Time.zone.parse('2000-01-01 08:00'),
      end_time: Time.zone.parse('2000-01-01 13:00'),
      price_per_slot_cents: 10_000,
      position: 0
    )

    result = PricingEngine.calculate(@space, @user, @start_at, 2)

    assert_equal 20_000, result[:subtotal_cents]
  end
end
