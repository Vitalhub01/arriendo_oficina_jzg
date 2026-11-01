# frozen_string_literal: true

class AllowNullBookingIdOnPayments < ActiveRecord::Migration[8.0]
  def change
    change_column_null :payments, :booking_id, true
  end
end
