# frozen_string_literal: true

class MaintainScheduleBlocksJob < ApplicationJob
  queue_as :default

  def perform
    Space.published_spaces.find_each do |space|
      next if space.schedule_blocks.exists?

      next if ScheduleBlocks::GenerateFromRules.call(space)
      next unless ScheduleBlocks::SeedDefaults.call(space).success?
    end
  end
end
