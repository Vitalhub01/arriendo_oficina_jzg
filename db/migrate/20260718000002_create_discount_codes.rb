# frozen_string_literal: true

class CreateDiscountCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :discount_codes do |t|
      t.string :code, null: false
      t.integer :discount_type, default: 0, null: false
      t.integer :percent
      t.integer :amount_cents
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :active, default: true, null: false
      t.integer :max_uses
      t.integer :redemptions_count, default: 0, null: false

      t.timestamps
    end

    add_index :discount_codes, 'lower(code)', unique: true, name: 'index_discount_codes_on_lower_code'

    add_reference :bookings, :discount_code, foreign_key: true
    add_column :bookings, :promo_discount_cents, :integer, default: 0, null: false
  end
end
