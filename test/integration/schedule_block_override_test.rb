# frozen_string_literal: true

require 'test_helper'

class ScheduleBlockOverrideTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @space = boxes(:published_box)
    @block = @space.schedule_blocks.first
    @date = Date.current.beginning_of_week(:monday) + 2.days
  end

  test 'upsert override with custom times via json' do
    sign_in @admin

    post override_admin_space_schedule_block_path(@space, @block),
         params: {
           date: @date.iso8601,
           start_time: '15:00',
           end_time: '16:30',
           week_start: Date.current.beginning_of_week(:monday).iso8601
         },
         as: :json

    assert_response :success
    override = @block.overrides.find_by(date: @date)
    assert_equal '16:30', override.end_time.strftime('%H:%M')
  end

  test 'override with overlap blocks conflicting slot only on that date' do
    sign_in @admin
    day = (@date.wday + 6) % 7
    first = @space.schedule_blocks.create!(
      day_of_week: day,
      start_time: '15:00',
      end_time: '16:00',
      price_cents: 5000,
      position: 0
    )
    second = @space.schedule_blocks.create!(
      day_of_week: day,
      start_time: '16:00',
      end_time: '17:00',
      price_cents: 5000,
      position: 1
    )

    post override_admin_space_schedule_block_path(@space, first),
         params: {
           date: @date.iso8601,
           start_time: '15:00',
           end_time: '16:30',
           block_overlapping_ids: [second.id],
           week_start: Date.current.beginning_of_week(:monday).iso8601
         },
         as: :json

    assert_response :success
    assert first.overrides.find_by(date: @date)&.end_time&.strftime('%H:%M') == '16:30'
    assert second.overrides.find_by(date: @date)&.blocked?
    assert_not second.blocked_on?(@date + 7.days)
  end

  test 'end series from date hides block on and after that date' do
    sign_in @admin
    day = (@date.wday + 6) % 7
    block = @space.schedule_blocks.for_day(day).first!
    prior_week = @date - 7.days

    post end_series_admin_space_schedule_block_path(@space, block),
         params: { from_date: @date.iso8601, week_start: Date.current.beginning_of_week(:monday).iso8601 },
         as: :json

    assert_response :success
    block.reload
    assert_equal @date - 1.day, block.effective_until
    assert block.active_on?(prior_week)
    assert_not block.active_on?(@date)
    assert_not block.active_on?(@date + 7.days)
  end
end
