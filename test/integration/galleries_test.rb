# frozen_string_literal: true

require 'test_helper'

class GalleriesTest < ActionDispatch::IntegrationTest
  test 'home shows one cover photo per tag with count' do
    item = GalleryItem.create!(position: 0, tag: 'Recepción', visible: true)
    item.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )

    get root_path
    assert_response :success
    assert_match 'Recepción', response.body
    assert_match '(1)', response.body
    assert_match gallery_path(tag: item.tag_slug), response.body
  end

  test 'show displays photo set for tag slug' do
    item = GalleryItem.create!(position: 0, tag: 'Box clínico', visible: true)
    item.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )

    get gallery_path(tag: item.tag_slug, photo_id: item.id)
    assert_response :success
    assert_match 'Box clínico', response.body
    assert_match '/rails/active_storage/', response.body
  end

  test 'unknown tag returns not found' do
    get gallery_path(tag: 'no-existe')
    assert_response :not_found
  end
end
