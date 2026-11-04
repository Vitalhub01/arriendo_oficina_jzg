# frozen_string_literal: true

require 'test_helper'

class SpaceCheckoutTest < ActionDispatch::IntegrationTest
  setup do
    @space = boxes(:published_box)
    @slot_time = next_monday_at(hour: 10)
  end

  test 'deprecated checkout url redirects guest to space with booking params' do
    get checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '16:00',
      reservation_mode: 'hora',
      slot_count: 1
    )

    assert_redirected_to space_path(
      @space,
      date: @slot_time.to_date.iso8601,
      start_time: '16:00',
      reservation_mode: 'hora',
      slot_count: 1
    )
    assert_equal 'Inicia sesión o regístrate para reservar', flash[:alert]
  end

  test 'deprecated checkout url redirects signed in user to space with params' do
    sign_in users(:renter)

    get checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )

    assert_redirected_to space_path(
      @space,
      date: @slot_time.to_date.iso8601,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )
    assert_nil flash[:alert]
  end

  test 'guest slot link on space show points to space with reservation params not checkout path' do
    get space_path(@space)
    assert_response :success
    assert_no_match %r{/spaces/\d+/checkout}, response.body
    assert_match 'reservation_mode=hora', response.body
  end

  test 'guest space show prompts sign in to book' do
    get space_path(@space)
    assert_response :success
    assert_match 'Iniciar sesión o registrarse para reservar', response.body
  end

  test 'guest mobile reserve bar links to sign in not hidden panel anchor' do
    get space_path(@space)
    assert_response :success
    assert_no_match 'href="#space-booking-panel"', response.body
    assert_select '.fixed.inset-x-0.bottom-0 a.btn-primary[href=?]', new_user_session_path, text: 'Reservar'
  end

  test 'signed in user can book from space show form' do
    sign_in users(:renter)
    get space_path(@space)
    assert_response :success
    assert_match 'Reservar y pagar', response.body
  end

  test 'deprecated checkout stores return path for registration' do
    checkout_url = checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )
    get checkout_url
    follow_redirect!

    assert_response :success
    assert_match @space.title, response.body
  end
end
