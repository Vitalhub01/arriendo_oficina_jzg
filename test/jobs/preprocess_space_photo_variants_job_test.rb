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

    processed_limits = []
    variant_proxy = Object.new
    variant_proxy.define_singleton_method(:processed) { self }

    photo.image.stub(:variant, lambda { |**kwargs|
      processed_limits << kwargs[:resize_to_limit]
      variant_proxy
    }) do
      PreprocessSpacePhotoVariantsJob.perform_now(photo.id)
    end

    assert_equal ImageVariantPreprocessor::SPACE_PHOTO_LIMITS, processed_limits
  end

  test 'no-op when photo was deleted' do
    assert_nothing_raised do
      PreprocessSpacePhotoVariantsJob.perform_now(-1)
    end
  end
end
