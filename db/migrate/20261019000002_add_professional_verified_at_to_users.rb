# frozen_string_literal: true

class AddProfessionalVerifiedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :professional_verified_at, :datetime
    add_index :users, :professional_verified_at
  end
end
