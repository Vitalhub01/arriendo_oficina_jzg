# frozen_string_literal: true

class AddWeekdaysToSpotOffers < ActiveRecord::Migration[8.0]
  def change
    add_column :spot_offers, :weekdays, :integer, array: true, default: [0, 1, 2, 3, 4, 5, 6], null: false
  end
end
