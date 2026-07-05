# frozen_string_literal: true

class MakeBoxOwnerOptional < ActiveRecord::Migration[8.0]
  def change
    change_column_null :boxes, :owner_id, true
  end
end
