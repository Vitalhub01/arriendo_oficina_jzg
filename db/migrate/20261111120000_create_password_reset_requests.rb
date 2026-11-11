# frozen_string_literal: true

class CreatePasswordResetRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :password_reset_requests do |t|
      t.string :email, null: false
      t.references :user, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :resolved_at
      t.references :resolved_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :password_reset_requests, :status
    add_index :password_reset_requests, :created_at
  end
end
