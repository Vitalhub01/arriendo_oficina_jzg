# frozen_string_literal: true

class CreateGalleryTags < ActiveRecord::Migration[8.0]
  def change
    create_table :gallery_tags do |t|
      t.string :label, null: false
      t.text :description

      t.timestamps
    end

    add_index :gallery_tags, :label, unique: true
  end
end
