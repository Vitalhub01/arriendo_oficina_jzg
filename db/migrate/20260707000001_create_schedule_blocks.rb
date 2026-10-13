# frozen_string_literal: true

class CreateScheduleBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_blocks do |t|
      t.references :space, null: false, foreign_key: { to_table: :boxes }
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :price_cents, null: false
      t.string :name
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :schedule_blocks, %i[space_id day_of_week position]
  end
end
