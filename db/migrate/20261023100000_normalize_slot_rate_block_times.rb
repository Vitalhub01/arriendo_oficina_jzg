# frozen_string_literal: true

class NormalizeSlotRateBlockTimes < ActiveRecord::Migration[8.0]
  class MigrationSlotRate < ApplicationRecord
    self.table_name = 'slot_rates'
  end

  def up
    morning_start = Time.zone.parse('2000-01-01 08:00')
    morning_end = Time.zone.parse('2000-01-01 14:00')
    afternoon_start = Time.zone.parse('2000-01-01 14:00')
    afternoon_end = Time.zone.parse('2000-01-01 20:00')

    MigrationSlotRate.where(name: 'Mañana').update_all(start_time: morning_start, end_time: morning_end)
    MigrationSlotRate.where(name: 'Tarde').update_all(start_time: afternoon_start, end_time: afternoon_end)
  end

  def down
    # no-op
  end
end
