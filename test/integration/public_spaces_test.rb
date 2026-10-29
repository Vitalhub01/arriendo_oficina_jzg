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
    assert_match 'data-availability-schedule-weeks-value', response.body
    assert_no_match '<template data-week-start', response.body
  end

  test 'availability returns schedule inside turbo frame' do
    get availability_space_path(boxes(:published_box))
    assert_response :success
    assert_match 'turbo-frame', response.body
    assert_match 'availability_schedule', response.body
    assert_match 'data-availability-schedule-weeks-value', response.body
  end

  test 'availability reloads schedule payload when week_start is beyond initial preload' do
    space = boxes(:published_box)
    week_start = 6.weeks.from_now.to_date.beginning_of_week(:monday)

    get availability_space_path(space, week_start: week_start), headers: { 'Accept' => 'application/json' }
    assert_response :success

    payload = JSON.parse(response.body)
    assert_equal 5, payload['weeks'].size
    assert_equal week_start.iso8601, payload['initialWeekStart']
    assert_equal week_start.iso8601, payload['weeks'].first['weekStart']
  end

  test 'show renders active storage image when space has photo' do
    space = boxes(:published_box)
    attach_box_photo(space)

    get space_path(space)
    assert_response :success
    assert_match %r{/rails/active_storage/}, response.body
    assert_match 'data-controller="photo-lightbox"', response.body
    assert_match 'cursor-zoom-in', response.body
  end

  test 'show calendar avoids per-cell booking existence queries' do
    space = boxes(:published_box)
    queries = []
    callback = lambda { |*, payload| queries << payload[:sql] if payload[:sql] }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      get space_path(space)
    end

    assert_response :success
    per_cell_booking_checks = queries.count { |sql| sql.match?(/SELECT 1 AS one FROM "bookings"/i) }
    assert_equal 0, per_cell_booking_checks,
                 'bloque/jornada templates must use precomputed schedule data, not AvailabilityChecker per day'
  end
end
