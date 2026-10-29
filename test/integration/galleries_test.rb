# frozen_string_literal: true

require 'test_helper'

class GalleriesTest < ActionDispatch::IntegrationTest
  test 'gallery frame serves cover image' do
    item = GalleryItem.create!(position: 0, tag: 'Pasillo', visible: true)
    item.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )

    get gallery_frame_path(item)
    assert_response :success
    assert_match '/rails/active_storage/', response.body
    assert_no_match 'animate-pulse', response.body
  end

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
    assert_match gallery_frame_path(item), response.body
  end

  test 'show displays main photo viewer for tag slug' do
    first = GalleryItem.create!(position: 0, tag: 'Box clínico', visible: true)
    first.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )
    second = GalleryItem.create!(position: 1, tag: 'Box clínico', visible: true)
    second.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover2.jpg',
      content_type: 'image/jpeg'
    )

    get gallery_path(tag: first.tag_slug, photo_id: second.id)
    assert_response :success
    assert_match 'Box clínico', response.body
    assert_match 'gallery_main_photo', response.body
    assert_match 'data-controller="gallery-set"', response.body
    assert_match 'Todas las fotos de la galería', response.body
    assert_match '/rails/active_storage/', response.body
  end

  test 'turbo frame request returns only main photo partial' do
    first = GalleryItem.create!(position: 0, tag: 'Recepción', visible: true)
    first.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )
    second = GalleryItem.create!(position: 1, tag: 'Recepción', visible: true)
    second.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover2.jpg',
      content_type: 'image/jpeg'
    )

    get gallery_path(tag: first.tag_slug, photo_id: second.id),
        headers: { 'Turbo-Frame' => 'gallery_main_photo' }

    assert_response :success
    assert_no_match '<!DOCTYPE html>', response.body
    assert_match 'turbo-frame id="gallery_main_photo"', response.body
    assert_match 'Todas las fotos de la galería', response.body
    assert_match gallery_path(tag: first.tag_slug, photo_id: first.id), response.body
    assert_match gallery_path(tag: first.tag_slug, photo_id: second.id), response.body
  end

  test 'show displays tag description when present' do
    item = GalleryItem.create!(position: 0, tag: 'Exterior', visible: true)
    item.image.attach(
      io: File.open(Rails.root.join('test/fixtures/files/cover.jpg')),
      filename: 'cover.jpg',
      content_type: 'image/jpeg'
    )
    GalleryTag.create!(label: 'Exterior', description: 'Vista del edificio y accesos.')

    get gallery_path(tag: item.tag_slug, photo_id: item.id)
    assert_response :success
    assert_match 'Vista del edificio y accesos.', response.body
  end

  test 'unknown tag returns not found' do
    get gallery_path(tag: 'no-existe')
    assert_response :not_found
  end
end
