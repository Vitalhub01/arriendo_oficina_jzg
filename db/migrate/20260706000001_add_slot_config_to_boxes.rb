# frozen_string_literal: true

class AddSlotConfigToBoxes < ActiveRecord::Migration[8.0]
  def change
    change_table :boxes, bulk: true do |t|
      t.integer :slot_duration_minutes, null: false, default: 60
      t.integer :minimum_slots, null: false, default: 1
    end
  end
end
