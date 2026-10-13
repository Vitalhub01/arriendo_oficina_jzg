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
end
