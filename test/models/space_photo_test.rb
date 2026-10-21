# frozen_string_literal: true

require 'test_helper'

class SpacePhotoTest < ActiveSupport::TestCase
  test 'enqueues variant preprocessing after create' do
    space = boxes(:draft_box)

    assert_enqueued_with(job: PreprocessSpacePhotoVariantsJob) do
      photo = space.space_photos.build
      photo.image.attach(
        io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
        filename: 'cover.jpg',
        content_type: 'image/jpeg'
      )
      photo.save!
    end
  end
end
