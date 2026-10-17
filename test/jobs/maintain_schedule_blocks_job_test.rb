# frozen_string_literal: true

require 'test_helper'

class MaintainScheduleBlocksJobTest < ActiveJob::TestCase
  test 'generates schedule blocks from rules for published space without template' do
    space = boxes(:published_box)
    space.schedule_blocks.destroy_all
    assert space.availability_rules.any?

    assert_changes -> { space.schedule_blocks.count }, from: 0 do
      MaintainScheduleBlocksJob.perform_now
    end
  end

  test 'does not duplicate blocks when template already exists' do
    space = boxes(:published_box)
    count = space.schedule_blocks.count

    assert_no_difference -> { space.schedule_blocks.count } do
      MaintainScheduleBlocksJob.perform_now
    end

    assert_equal count, space.schedule_blocks.count
  end
end
