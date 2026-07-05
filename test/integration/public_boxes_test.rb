# frozen_string_literal: true

require 'test_helper'

class PublicBoxesTest < ActionDispatch::IntegrationTest
  test 'index lists published boxes' do
    get boxes_path
    assert_response :success
    assert_match boxes(:published_box).title, response.body
  end

  test 'index filters by commune' do
    get boxes_path, params: { commune: boxes(:published_box).commune }
    assert_response :success
    assert_match boxes(:published_box).title, response.body
  end

  test 'index filters by date and hours availability' do
    slot = next_monday_at(hour: 10)
    get boxes_path, params: {
      date: slot.to_date.to_s,
      hours: 2,
      start_time: '10:00'
    }
    assert_response :success
    assert_match boxes(:published_box).title, response.body
  end

  test 'show displays published box with availability schedule' do
    get box_path(boxes(:published_box))
    assert_response :success
    assert_match boxes(:published_box).title, response.body
  end

  test 'availability returns schedule partial for a week' do
    get availability_box_path(boxes(:published_box))
    assert_response :success
  end
end
