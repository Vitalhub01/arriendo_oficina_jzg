# frozen_string_literal: true

require 'test_helper'

module Spaces
  class UpsertPricingTest < ActiveSupport::TestCase
    setup do
      @space = boxes(:published_box)
      attach_box_photo(@space) unless @space.photos_attached?
    end

    test 'creates slot rates jornada and syncs schedule block prices' do
      result = UpsertPricing.new(
        space: @space,
        params: {
          morning_hourly_price_cents: 7_000,
          afternoon_hourly_price_cents: 8_000,
          morning_block_price_cents: 30_000,
          afternoon_block_price_cents: 32_000,
          jornada_price_cents: 55_000
        }
      ).call

      assert result.success?
      morning = @space.slot_rates.find_by(name: 'Mañana')
      assert_equal '14:00', morning.end_time.strftime('%H:%M')
      assert_equal 7_000, morning.price_per_slot_cents
      assert_equal 30_000, morning.block_price_cents
      assert_equal 55_000, @space.primary_jornada_definition.price_cents
      assert_operator @space.schedule_blocks.where(price_cents: 7_000).count, :positive?
      assert_equal 7_000, @space.price_per_hour_cents
    end
  end
end
