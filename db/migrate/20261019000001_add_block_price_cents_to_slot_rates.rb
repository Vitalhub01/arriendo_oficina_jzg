# frozen_string_literal: true

class AddBlockPriceCentsToSlotRates < ActiveRecord::Migration[8.0]
  def up
    add_column :slot_rates, :block_price_cents, :integer

    execute <<-SQL.squish
      UPDATE slot_rates
      SET block_price_cents = price_per_slot_cents
      WHERE block_price_cents IS NULL
    SQL
  end

  def down
    remove_column :slot_rates, :block_price_cents
  end
end
