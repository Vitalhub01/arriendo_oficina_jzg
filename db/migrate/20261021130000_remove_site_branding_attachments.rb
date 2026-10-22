# frozen_string_literal: true

class RemoveSiteBrandingAttachments < ActiveRecord::Migration[8.0]
  def up
    purge_site_branding_attachments
    drop_table :site_brandings, if_exists: true
  end

  def down
    create_table :site_brandings do |t|
      t.timestamps
    end
  end

  private

  def purge_site_branding_attachments
    return unless table_exists?(:active_storage_attachments)

    attachments = ActiveStorage::Attachment.where(record_type: 'SiteBranding')
    attachments.find_each(&:purge)
  end
end
