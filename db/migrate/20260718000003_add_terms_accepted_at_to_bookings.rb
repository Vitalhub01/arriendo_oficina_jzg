# frozen_string_literal: true

class AddTermsAcceptedAtToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :terms_accepted_at, :datetime
  end
end
