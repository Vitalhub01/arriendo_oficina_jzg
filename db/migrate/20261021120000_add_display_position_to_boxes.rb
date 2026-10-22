# frozen_string_literal: true

class AddDisplayPositionToBoxes < ActiveRecord::Migration[8.0]
  def up
    add_column :boxes, :display_position, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE boxes
      SET display_position = sub.row_num
      FROM (
        SELECT id, ROW_NUMBER() OVER (ORDER BY created_at ASC, id ASC) - 1 AS row_num
        FROM boxes
      ) AS sub
      WHERE boxes.id = sub.id
    SQL
  end

  def down
    remove_column :boxes, :display_position
  end
end
