# frozen_string_literal: true

require 'test_helper'

module ScheduleBlocks
  class BulkFillTest < ActiveSupport::TestCase
    setup do
      @space = boxes(:published_box)
      @space.schedule_blocks.destroy_all
    end

    test 'creates hourly blocks for weekdays in range' do
      result = BulkFill.call(
        space: @space,
        days: [0, 1, 2, 3, 4],
        start_time: '08:00',
        end_time: '22:00',
        price_cents: 5000,
        replace_overlapping: false
      )

      assert result.success?
      assert_equal 70, result.created_count
      assert_equal 14, @space.schedule_blocks.for_day(0).count
      first_block = @space.schedule_blocks.for_day(0).order(:position).first
      assert_equal '08:00', first_block.start_time.strftime('%H:%M')
      assert_equal '09:00', first_block.end_time.strftime('%H:%M')
      assert_equal 5000, first_block.price_cents
    end

    test 'replaces overlapping blocks when requested' do
      @space.schedule_blocks.create!(
        day_of_week: 0,
        start_time: '09:00',
        end_time: '10:00',
        price_cents: 1000,
        position: 0
      )

      result = BulkFill.call(
        space: @space,
        days: [0],
        start_time: '08:00',
        end_time: '11:00',
        price_cents: 5000,
        replace_overlapping: true
      )

      assert result.success?
      assert_equal 1, result.removed_count
      assert_equal 3, result.created_count
      assert_equal 3, @space.schedule_blocks.for_day(0).count
    end
  end
end
