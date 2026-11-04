# frozen_string_literal: true

class ExpandDiscountCodeRestrictions < ActiveRecord::Migration[8.0]
  def change
    add_column :discount_codes, :max_uses_per_user, :integer
    add_column :discount_codes, :allowed_weekdays, :integer, array: true, default: [], null: false
    add_column :discount_codes, :allowed_time_windows, :jsonb, default: [], null: false
    add_column :discount_codes, :allowed_space_ids, :bigint, array: true, default: [], null: false
  end
end
