# frozen_string_literal: true

class AddRescheduleAndManualConfirmToBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :boxes, :reschedule_notice_hours, :integer
    add_column :bookings, :manually_confirmed_at, :datetime
  end
end
