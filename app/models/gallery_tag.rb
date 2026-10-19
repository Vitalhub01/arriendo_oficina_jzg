# frozen_string_literal: true

class GalleryTag < ApplicationRecord
  validates :label, presence: true, uniqueness: true

  scope :ordered, -> { order(:label) }

  def self.description_for_label(label)
    find_by(label: label)&.description&.presence
  end

  def self.sync_from_gallery_items!
    GalleryItem.distinct_tag_labels.each do |label|
      find_or_create_by!(label: label)
    end
  end
end
