# frozen_string_literal: true

class CreateAvailabilityBlocks < ActiveRecord::Migration[7.0]
  def change
    create_table :availability_blocks do |t|
      t.references :box, null: false, foreign_key: true
      t.datetime :start_at, null: false
      t.datetime :end_at, null: false
      t.string :reason

      t.timestamps
    end

    add_index :availability_blocks, %i[box_id start_at end_at]
  end
end
