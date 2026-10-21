# frozen_string_literal: true

class PreprocessSpacePhotoVariantsJob < ApplicationJob
  queue_as :default

  def perform(space_photo_id)
    photo = SpacePhoto.find_by(id: space_photo_id)
    return unless photo&.image&.attached?

    ImageVariantPreprocessor.preprocess!(photo.image, ImageVariantPreprocessor::SPACE_PHOTO_LIMITS)
  end
end
