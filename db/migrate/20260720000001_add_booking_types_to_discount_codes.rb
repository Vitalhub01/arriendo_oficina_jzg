# frozen_string_literal: true

class AddBookingTypesToDiscountCodes < ActiveRecord::Migration[8.0]
  def change
    add_column :discount_codes, :applies_to_hourly, :boolean, default: true, null: false
    add_column :discount_codes, :applies_to_slot_based, :boolean, default: true, null: false
    add_column :discount_codes, :applies_to_jornada, :boolean, default: true, null: false
  end
end
