# frozen_string_literal: true

class AddPaymentExpiresAtToBookings < ActiveRecord::Migration[7.0]
  def change
    add_column :bookings, :payment_expires_at, :datetime
    add_index :bookings, %i[status payment_expires_at]

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE bookings
          SET payment_expires_at = created_at + INTERVAL '30 minutes'
          WHERE status = 0 AND payment_expires_at IS NULL
        SQL
      end
    end
  end
end
