# frozen_string_literal: true

class AddTimesToScheduleBlockOverrides < ActiveRecord::Migration[8.0]
  def change
    change_table :schedule_block_overrides, bulk: true do |t|
      t.time :start_time
      t.time :end_time
    end
  end
end
