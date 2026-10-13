# frozen_string_literal: true

class AddEffectiveUntilToScheduleBlocks < ActiveRecord::Migration[8.0]
  def change
    add_column :schedule_blocks, :effective_until, :date
  end
end
