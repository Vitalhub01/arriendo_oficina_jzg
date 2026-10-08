# frozen_string_literal: true

require 'test_helper'

class PublicSpacesTest < ActionDispatch::IntegrationTest
  test 'index lists published spaces' do
    get spaces_path
    assert_response :success
    assert_match boxes(:published_box).title, response.body
  end

  test 'index filters by commune' do
    get spaces_path, params: { commune: boxes(:published_box).commune }
    assert_response :success
    assert_match boxes(:published_box).title, response.body
  end

  test 'index filters by date and hours availability' do
    slot = next_monday_at(hour: 10)
    get spaces_path, params: {
      date: slot.to_date.to_s,
      hours: 2,
      start_time: '10:00'
    }
    assert_response :success
    assert_match boxes(:published_box).title, response.body
  end

  test 'show displays published space with availability schedule' do
    get space_path(boxes(:published_box))
    assert_response :success
    assert_match boxes(:published_box).title, response.body
  end

  test 'availability returns schedule partial for a week' do
    get availability_space_path(boxes(:published_box))
    assert_response :success
  end

  test 'show renders active storage image when space has photo' do
    space = boxes(:published_box)
    attach_box_photo(space)

    get space_path(space)
    assert_response :success
    assert_match %r{/rails/active_storage/}, response.body
  end
end
