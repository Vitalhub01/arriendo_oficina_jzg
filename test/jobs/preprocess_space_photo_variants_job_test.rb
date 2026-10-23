# frozen_string_literal: true

require 'test_helper'

class PreprocessSpacePhotoVariantsJobTest < ActiveJob::TestCase
  test 'preprocesses all configured limits for attached image' do
    space = boxes(:draft_box)
    photo = space.space_photos.build
    photo.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )
    photo.save!

    captured_limits = nil
    ImageVariantPreprocessor.stub(:preprocess!, lambda { |_attachment, limits|
      captured_limits = limits
    }) do
      PreprocessSpacePhotoVariantsJob.perform_now(photo.id)
    end

    assert_equal ImageVariantPreprocessor::SPACE_PHOTO_LIMITS, captured_limits
  end

  test 'no-op when photo was deleted' do
    assert_nothing_raised do
      PreprocessSpacePhotoVariantsJob.perform_now(-1)
    end
  end
end
