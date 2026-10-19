# frozen_string_literal: true

require 'test_helper'

class AdminGalleryTagsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in @admin
  end

  test 'index lists tags from gallery items' do
    item = GalleryItem.create!(position: 0, tag: 'Recepción', visible: true)
    item.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )

    get admin_gallery_tags_path
    assert_response :success
    assert_match 'Recepción', response.body
    assert_match 'Descripciones de galería', response.body
  end

  test 'update description' do
    item = GalleryItem.create!(position: 0, tag: 'Sala común', visible: true)
    item.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )
    GalleryTag.sync_from_gallery_items!
    gallery_tag = GalleryTag.find_by!(label: 'Sala común')

    patch admin_gallery_tag_path(gallery_tag), params: {
      gallery_tag: { description: 'Espacio amplio para descanso entre consultas.' }
    }

    assert_redirected_to admin_gallery_tags_path
    assert_equal 'Espacio amplio para descanso entre consultas.', gallery_tag.reload.description
  end
end
