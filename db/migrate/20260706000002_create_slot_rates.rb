# frozen_string_literal: true

class CreateSlotRates < ActiveRecord::Migration[8.0]
  def change
    create_table :slot_rates do |t|
      t.references :space, null: false, foreign_key: { to_table: :boxes }
      t.string :name, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :price_per_slot_cents, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :slot_rates, %i[space_id position]
  end
end
