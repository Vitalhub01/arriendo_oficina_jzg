# frozen_string_literal: true

class CreateGalleryItems < ActiveRecord::Migration[8.0]
  def change
    create_table :gallery_items do |t|
      t.integer :position, null: false, default: 0
      t.string :tag
      t.string :alt_text
      t.boolean :visible, null: false, default: true

      t.timestamps
    end

    add_index :gallery_items, :position
  end
end
