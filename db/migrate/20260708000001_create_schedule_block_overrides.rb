# frozen_string_literal: true

class CreateScheduleBlockOverrides < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_block_overrides do |t|
      t.references :schedule_block, null: false, foreign_key: true
      t.references :space, null: false, foreign_key: { to_table: :boxes }
      t.date :date, null: false
      t.boolean :blocked, default: false, null: false
      t.integer :price_cents
      t.string :reason

      t.timestamps
    end

    add_index :schedule_block_overrides, %i[schedule_block_id date], unique: true
    add_index :schedule_block_overrides, %i[space_id date]
  end
end
