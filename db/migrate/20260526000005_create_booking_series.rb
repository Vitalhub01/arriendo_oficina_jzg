# frozen_string_literal: true

class CreateBookingSeries < ActiveRecord::Migration[7.0]
  def change
    create_table :booking_series do |t|
      t.references :box, null: false, foreign_key: true
      t.references :renter, null: false, foreign_key: { to_table: :users }
      t.integer :day_of_week, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :booking_series, %i[box_id status]
  end
end
