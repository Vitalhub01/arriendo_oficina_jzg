# frozen_string_literal: true

class AddDurationMinutesToBookings < ActiveRecord::Migration[8.0]
  def up
    add_column :bookings, :duration_minutes, :integer

    execute <<~SQL.squish
      UPDATE bookings
      SET duration_minutes = hours * 60
      WHERE duration_minutes IS NULL
    SQL

    change_column_null :bookings, :duration_minutes, false
  end

  def down
    remove_column :bookings, :duration_minutes
  end
end
