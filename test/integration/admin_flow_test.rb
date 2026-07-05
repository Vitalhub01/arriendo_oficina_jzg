# frozen_string_literal: true

require 'test_helper'

class AdminFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @renter = users(:renter)
    @published = boxes(:published_box)
  end

  test 'admin dashboard shows metrics' do
    sign_in @admin
    get admin_root_path
    assert_response :success
    assert_match 'Boxes', response.body
    assert_match 'Reservas', response.body
  end

  test 'admin creates owner user' do
    sign_in @admin

    assert_difference -> { User.owner.count }, 1 do
      post admin_users_path, params: {
        user: {
          name: 'Nuevo Dueño',
          email: 'nuevo-owner@test.com',
          role: 'owner',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
    end

    assert_redirected_to admin_users_path
    assert User.exists?(email: 'nuevo-owner@test.com', role: 'owner')
  end

  test 'admin suspends box and it disappears from public catalog' do
    sign_in @admin

    patch admin_box_path(@published), params: { box: { status: 'suspended' } }
    assert_redirected_to admin_boxes_path
    assert @published.reload.suspended?

    get boxes_path
    assert_no_match @published.title, response.body
  end

  test 'non-admin cannot access admin panel' do
    sign_in @renter
    get admin_root_path
    assert_redirected_to root_path
    assert_match 'Acceso no autorizado', flash[:alert]
  end
end
