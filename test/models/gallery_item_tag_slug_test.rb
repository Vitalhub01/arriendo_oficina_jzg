# frozen_string_literal: true

require 'test_helper'

class GalleryItemTagSlugTest < ActiveSupport::TestCase
  test 'items_for_tag_slug loads only matching tag' do
    GalleryItem.visible.delete_all

    recepcion = GalleryItem.create!(tag: 'Recepción', position: 0, visible: true)
    recepcion.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )

    other = GalleryItem.create!(tag: 'Box clínico', position: 0, visible: true)
    other.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover2.jpg',
      content_type: 'image/jpeg'
    )

    items = GalleryItem.items_for_tag_slug('recepcion')
    assert_equal 1, items.size
    assert_equal recepcion.id, items.first.id
  end
end
