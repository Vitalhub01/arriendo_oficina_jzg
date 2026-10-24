# frozen_string_literal: true

require 'test_helper'

class SpaceCheckoutTest < ActionDispatch::IntegrationTest
  setup do
    @space = boxes(:published_box)
    @slot_time = next_monday_at(hour: 10)
  end

  test 'guest can open checkout with slot params' do
    get checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )

    assert_response :success
    assert_match 'Confirmar reserva', response.body
    assert_match 'Iniciar sesión', response.body
    assert_match 'Registrarse', response.body
    assert_match @space.title, response.body
  end

  test 'guest slot link on space show points to checkout' do
    get space_path(@space)
    assert_response :success
    assert_match 'checkout', response.body
    assert_match 'reservation_mode=hora', response.body
  end

  test 'signed in user sees confirm and pay on checkout' do
    sign_in users(:renter)

    get checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )

    assert_response :success
    assert_match 'Confirmar y pagar', response.body
    assert_no_match 'Iniciar sesión', response.body
  end

  test 'checkout stores return path for sign in' do
    checkout_url = checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )
    get checkout_url
    assert_response :success

    sign_in users(:renter)
    follow_redirect! if response.redirect?
    get checkout_url
    assert_response :success
  end
end
