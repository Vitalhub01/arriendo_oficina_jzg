# frozen_string_literal: true

class PreprocessGalleryItemVariantsJob < ApplicationJob
  queue_as :default

  def perform(gallery_item_id)
    item = GalleryItem.find_by(id: gallery_item_id)
    return unless item&.image&.attached?

    ImageVariantPreprocessor.preprocess!(item.image, ImageVariantPreprocessor::GALLERY_ITEM_LIMITS)
  end
end
