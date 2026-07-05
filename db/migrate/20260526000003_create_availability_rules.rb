# frozen_string_literal: true

class CreateAvailabilityRules < ActiveRecord::Migration[7.0]
  def change
    create_table :availability_rules do |t|
      t.references :box, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.date :valid_from
      t.date :valid_until

      t.timestamps
    end

    add_index :availability_rules, %i[box_id day_of_week]
  end
end
