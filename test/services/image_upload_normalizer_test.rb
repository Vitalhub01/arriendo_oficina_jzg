# frozen_string_literal: true

require 'test_helper'

class ImageUploadNormalizerTest < ActiveSupport::TestCase
  test 'leaves small images unchanged' do
    space = boxes(:draft_box)
    photo = space.space_photos.build
    photo.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )

    original_key = photo.image.blob.key
    photo.save!

    assert_equal original_key, photo.image.blob.key
    assert photo.image.blob.metadata[ImageUploadNormalizer::METADATA_KEY].blank?
  end
end
