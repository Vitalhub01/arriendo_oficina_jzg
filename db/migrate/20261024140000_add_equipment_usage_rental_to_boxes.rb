# frozen_string_literal: true

class AddEquipmentUsageRentalToBoxes < ActiveRecord::Migration[8.0]
  def change
    change_table :boxes, bulk: true do |t|
      t.integer :equipment_usage_price_per_hour_cents
      t.string :equipment_usage_label
    end
  end
end
