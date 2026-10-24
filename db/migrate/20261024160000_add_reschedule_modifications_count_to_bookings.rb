# frozen_string_literal: true

class AddRescheduleModificationsCountToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :bookings, :reschedule_modifications_count, :integer, null: false, default: 0
  end
end
