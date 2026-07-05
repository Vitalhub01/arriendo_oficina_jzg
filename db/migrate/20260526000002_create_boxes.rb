# frozen_string_literal: true

class CreateBoxes < ActiveRecord::Migration[7.0]
  def change
    create_table :boxes do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.string :address, null: false
      t.string :commune, null: false
      t.string :city, null: false, default: 'Santiago'
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.integer :box_type, null: false, default: 0
      t.integer :price_per_hour_cents, null: false, default: 0
      t.integer :minimum_hours, null: false, default: 1
      t.integer :status, null: false, default: 0
      t.jsonb :amenities, null: false, default: {}

      t.timestamps
    end

    add_index :boxes, :status
    add_index :boxes, :box_type
    add_index :boxes, :city
    add_index :boxes, :commune
  end
end
