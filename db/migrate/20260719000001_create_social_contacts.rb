# frozen_string_literal: true

class CreateSocialContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :social_contacts do |t|
      t.string :name, null: false
      t.string :username
      t.string :url, null: false
      t.integer :position, default: 0, null: false
      t.boolean :visible, default: true, null: false

      t.timestamps
    end
  end
end
