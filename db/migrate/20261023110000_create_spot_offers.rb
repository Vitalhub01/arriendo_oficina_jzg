# frozen_string_literal: true

class CreateSpotOffers < ActiveRecord::Migration[8.0]
  def change
    create_table :spot_offers do |t|
      t.references :space, null: false, foreign_key: { to_table: :boxes }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :profesional, foreign_key: { to_table: :users }
      t.string :token, null: false
      t.string :title
      t.integer :total_price_cents, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.time :daily_start_time, null: false
      t.time :daily_end_time, null: false
      t.integer :status, null: false, default: 0
      t.integer :occurrence_count, null: false, default: 0
      t.timestamps
    end

    add_index :spot_offers, :token, unique: true

    add_reference :bookings, :spot_offer, foreign_key: true
    add_reference :payments, :spot_offer, foreign_key: true
  end
end
