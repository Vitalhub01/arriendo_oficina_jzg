# frozen_string_literal: true

class CreateReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :reviews do |t|
      t.references :box, null: false, foreign_key: true
      t.references :renter, null: false, foreign_key: { to_table: :users }
      t.references :booking, null: false, foreign_key: true, index: { unique: true }
      t.integer :rating, null: false
      t.text :body
      t.boolean :visible, default: true, null: false
      t.timestamps
    end
  end
end
