# frozen_string_literal: true

class AddBannedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :banned_at, :datetime
    add_index :users, :banned_at
  end
end
