# frozen_string_literal: true

class CreateHomeHighlights < ActiveRecord::Migration[8.0]
  DEFAULTS = [
    ['Flexibilidad', 'Bloques a tu medida', 0],
    ['Equipado', 'Listo para atender', 1],
    ['Ubicación', '{ciudad}', 2],
    ['Reserva online', 'Simple y rápida', 3]
  ].freeze

  def up
    create_table :home_highlights do |t|
      t.string :title, null: false
      t.string :description, null: false
      t.integer :position, default: 0, null: false
      t.boolean :visible, default: true, null: false

      t.timestamps
    end

    timestamp = Time.current
    rows = DEFAULTS.map do |title, description, position|
      {
        title: title,
        description: description,
        position: position,
        visible: true,
        created_at: timestamp,
        updated_at: timestamp
      }
    end
    HomeHighlight.insert_all(rows)
  end

  def down
    drop_table :home_highlights
  end
end
