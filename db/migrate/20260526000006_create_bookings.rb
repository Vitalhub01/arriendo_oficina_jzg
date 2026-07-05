# frozen_string_literal: true

class CreateBookings < ActiveRecord::Migration[7.0]
  def change
    create_table :bookings do |t|
      t.references :box, null: false, foreign_key: true
      t.references :renter, null: false, foreign_key: { to_table: :users }
      t.references :booking_series, foreign_key: true
      t.datetime :start_at, null: false
      t.datetime :end_at, null: false
      t.integer :hours, null: false
      t.integer :status, null: false, default: 0
      t.integer :total_amount_cents, null: false, default: 0

      t.timestamps
    end

    add_index :bookings, %i[box_id start_at end_at]
    add_index :bookings, %i[renter_id status]
  end
end
