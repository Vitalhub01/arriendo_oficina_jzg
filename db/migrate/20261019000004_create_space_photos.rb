# frozen_string_literal: true

class CreateSpacePhotos < ActiveRecord::Migration[8.0]
  def up
    create_table :space_photos do |t|
      t.bigint :box_id, null: false
      t.integer :position, null: false, default: 0
      t.string :caption

      t.timestamps
    end

    add_index :space_photos, %i[box_id position]
    add_foreign_key :space_photos, :boxes, column: :box_id

    migrate_space_attachments_to_space_photos
  end

  def down
    drop_table :space_photos
  end

  private

  def migrate_space_attachments_to_space_photos
    attachments = ActiveStorage::Attachment
                  .where(record_type: %w[Space Box], name: 'photos')
                  .order(:record_id, :id)

    attachments.group_by(&:record_id).each do |box_id, atts|
      atts.each_with_index do |attachment, index|
        execute <<-SQL.squish
          INSERT INTO space_photos (box_id, position, created_at, updated_at)
          VALUES (#{box_id.to_i}, #{index}, NOW(), NOW())
        SQL
        space_photo_id = select_value('SELECT MAX(id) FROM space_photos')

        execute <<-SQL.squish
          UPDATE active_storage_attachments
          SET record_type = 'SpacePhoto', record_id = #{space_photo_id.to_i}, name = 'image'
          WHERE id = #{attachment.id}
        SQL
      end
    end
  end
end
