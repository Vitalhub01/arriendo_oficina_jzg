# frozen_string_literal: true

class AddSpaceIdToPricingRules < ActiveRecord::Migration[8.0]
  def change
    add_reference :pricing_rules, :space, foreign_key: { to_table: :boxes }, index: true
  end
end
