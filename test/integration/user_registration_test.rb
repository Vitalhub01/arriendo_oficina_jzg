# frozen_string_literal: true

require 'test_helper'

class UserRegistrationTest < ActionDispatch::IntegrationTest
  test 'invalid registration shows flash alert and field errors on sign up page' do
    post user_registration_path, params: {
      user: {
        name: '',
        rut: '',
        email: 'nuevo@test.com',
        password: 'password123',
        password_confirmation: 'password123'
      }
    }

    assert_response :unprocessable_entity
    assert_match 'No pudimos crear tu cuenta', response.body
    assert_match 'data-controller="flash"', response.body
    assert_match 'registration-errors', response.body
  end

  test 'duplicate email shows descriptive flash alert' do
    post user_registration_path, params: {
      user: {
        name: 'Nuevo Profesional',
        rut: '11111111-1',
        email: users(:profesional).email,
        password: 'password123',
        password_confirmation: 'password123'
      }
    }

    assert_response :unprocessable_entity
    assert_match 'No pudimos crear tu cuenta. Revisa los datos', response.body
    assert_match 'registration-errors', response.body
  end

  test 'duplicate rut shows feedback without server error' do
    post user_registration_path, params: {
      user: {
        name: 'Otro Profesional',
        rut: professional_profiles(:renter_profile).rut,
        email: 'nuevo-rut@test.com',
        password: 'password123',
        password_confirmation: 'password123'
      }
    }

    assert_response :unprocessable_entity
    assert_match 'No pudimos crear tu cuenta', response.body
    assert_match 'registration-profile-errors', response.body
    assert_nil User.find_by(email: 'nuevo-rut@test.com')
  end

  test 'failed registration from space booking flow redirects back with flash' do
    space = boxes(:published_box)
    space_url = space_path(
      space,
      date: next_monday_at(hour: 10).to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )

    get space_url
    assert_response :success

    post user_registration_path,
         params: {
           user: {
             name: 'Checkout Guest',
             rut: '',
             email: 'checkout-guest@test.com',
             password: 'password123',
             password_confirmation: 'password123'
           }
         },
         headers: { 'HTTP_REFERER' => space_url }

    assert_redirected_to space_url
    follow_redirect!
    assert_response :success
    assert_match 'No pudimos crear tu cuenta:', response.body
    assert_match 'data-controller="flash"', response.body
    assert_match space.title, response.body
  end
end
