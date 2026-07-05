# frozen_string_literal: true

class AddUniqueIndexToPaymentsBookingId < ActiveRecord::Migration[7.0]
  def change
    remove_index :payments, :booking_id, if_exists: true
    add_index :payments, :booking_id, unique: true
  end
end
