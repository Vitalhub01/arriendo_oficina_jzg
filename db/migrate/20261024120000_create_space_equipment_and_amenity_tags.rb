# frozen_string_literal: true

class CreateSpaceEquipmentAndAmenityTags < ActiveRecord::Migration[8.0]
  class MigrationSpace < ApplicationRecord
    self.table_name = 'boxes'
  end

  class MigrationEquipmentItem < ApplicationRecord
    self.table_name = 'equipment_items'
  end

  class MigrationAmenityTag < ApplicationRecord
    self.table_name = 'amenity_tags'
  end

  class MigrationSpaceEquipmentItem < ApplicationRecord
    self.table_name = 'space_equipment_items'
  end

  class MigrationSpaceAmenityAssignment < ApplicationRecord
    self.table_name = 'space_amenity_assignments'
  end

  AMENITY_KEY_LABELS = {
    'wifi' => 'WiFi',
    'bathroom' => 'Baño',
    'parking' => 'Estacionamiento',
    'air_conditioning' => 'Aire acondicionado',
    'waiting_room' => 'Sala de espera',
    'wheelchair_access' => 'Acceso silla de ruedas'
  }.freeze

  def up
    create_table :equipment_items do |t|
      t.string :name, null: false
      t.integer :position, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :equipment_items, :name, unique: true

    create_table :amenity_tags do |t|
      t.string :name, null: false
      t.integer :position, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :amenity_tags, :name, unique: true

    create_table :space_equipment_items do |t|
      t.references :space, null: false, foreign_key: { to_table: :boxes }
      t.references :equipment_item, null: false, foreign_key: true
      t.timestamps
    end
    add_index :space_equipment_items, %i[space_id equipment_item_id], unique: true

    create_table :space_amenity_assignments do |t|
      t.references :space, null: false, foreign_key: { to_table: :boxes }
      t.references :amenity_tag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :space_amenity_assignments, %i[space_id amenity_tag_id],
              unique: true, name: 'index_space_amenity_assignments_on_space_and_tag'

    seed_default_catalog
    migrate_legacy_space_data

    remove_column :boxes, :equipment
    remove_column :boxes, :amenities
  end

  def down
    add_column :boxes, :equipment, :jsonb, default: [], null: false
    add_column :boxes, :amenities, :jsonb, default: {}, null: false

    drop_table :space_amenity_assignments
    drop_table :space_equipment_items
    drop_table :amenity_tags
    drop_table :equipment_items
  end

  private

  def seed_default_catalog
    default_equipment = [
      'Sillón', 'Té', 'WiFi', 'Timbre independiente', 'Iluminación regulable',
      'Camilla', 'Pizarra', 'Proyector', 'Mesa'
    ]
    default_equipment.each_with_index do |name, index|
      MigrationEquipmentItem.find_or_create_by!(name: name) do |item|
        item.position = index
        item.active = true
      end
    end

    AMENITY_KEY_LABELS.values.each_with_index do |name, index|
      MigrationAmenityTag.find_or_create_by!(name: name) do |tag|
        tag.position = index
        tag.active = true
      end
    end
  end

  def migrate_legacy_space_data
    MigrationSpace.find_each do |space|
      Array(space.equipment).each do |raw_name|
        name = raw_name.to_s.strip
        next if name.blank?

        item = MigrationEquipmentItem.find_or_create_by!(name: name) do |record|
          record.position = MigrationEquipmentItem.count
          record.active = true
        end
        MigrationSpaceEquipmentItem.find_or_create_by!(space_id: space.id, equipment_item_id: item.id)
      end

      amenities = space.amenities.is_a?(Hash) ? space.amenities : {}
      amenities.each do |key, enabled|
        next unless enabled == true || enabled.to_s == '1'

        label = AMENITY_KEY_LABELS[key.to_s] || key.to_s.humanize
        tag = MigrationAmenityTag.find_or_create_by!(name: label) do |record|
          record.position = MigrationAmenityTag.count
          record.active = true
        end
        MigrationSpaceAmenityAssignment.find_or_create_by!(space_id: space.id, amenity_tag_id: tag.id)
      end
    end
  end
end
