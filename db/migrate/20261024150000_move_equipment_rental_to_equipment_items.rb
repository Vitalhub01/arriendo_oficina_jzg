# frozen_string_literal: true

class MoveEquipmentRentalToEquipmentItems < ActiveRecord::Migration[8.0]
  def change
    add_column :equipment_items, :price_per_hour_cents, :integer

    change_table :boxes, bulk: true do |t|
      t.remove :equipment_usage_price_per_hour_cents, type: :integer
      t.remove :equipment_usage_label, type: :string
    end
  end
end
