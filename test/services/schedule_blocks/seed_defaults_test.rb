# frozen_string_literal: true

require 'test_helper'

module ScheduleBlocks
  class SeedDefaultsTest < ActiveSupport::TestCase
    setup do
      @space = boxes(:draft_box)
      @space.schedule_blocks.destroy_all
      Spaces::UpsertPricing.new(space: @space, params: admin_pricing_params).call
    end

    test 'creates default weekly template' do
      result = SeedDefaults.call(@space)

      assert result.success?
      assert_equal 68, @space.schedule_blocks.count
      assert_equal 12, @space.schedule_blocks.for_day(0).count
      assert_equal 8, @space.schedule_blocks.for_day(5).count
      assert_equal 0, @space.schedule_blocks.for_day(6).count

      monday_morning = @space.schedule_blocks.for_day(0).order(:start_time).first
      assert_equal '08:00', monday_morning.start_time.strftime('%H:%M')
      assert_equal '09:00', monday_morning.end_time.strftime('%H:%M')

      afternoon_cutoff = Time.zone.parse('2000-01-01 14:00')
      saturday_afternoon = @space.schedule_blocks.for_day(5).select { |b| b.start_time >= afternoon_cutoff }.sort_by(&:start_time)
      assert_equal 2, saturday_afternoon.size
      assert_equal '16:00', saturday_afternoon.last.end_time.strftime('%H:%M')
    end

    test 'is idempotent when blocks already exist' do
      SeedDefaults.call(@space)
      count_before = @space.schedule_blocks.count

      result = SeedDefaults.call(@space)

      assert result.success?
      assert_equal count_before, @space.schedule_blocks.count
    end
  end
end
