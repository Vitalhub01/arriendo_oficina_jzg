# frozen_string_literal: true

class MaintainScheduleBlocksJob < ApplicationJob
  queue_as :default

  def perform
    Space.published_spaces.find_each do |space|
      next if space.schedule_blocks.exists?

      ScheduleBlocks::GenerateFromRules.call(space)
    end
  end
end
