# frozen_string_literal: true

require 'test_helper'

class AdminUsersTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @profesional = users(:profesional)
  end

  test 'admin lists users' do
    sign_in @admin
    get admin_users_path
    assert_response :success
    assert_match 'Usuarios y permisos', response.body
    assert_match @profesional.email, response.body
  end

  test 'admin updates user role' do
    sign_in @admin
    patch admin_user_path(@profesional), params: {
      user: { name: @profesional.name, email: @profesional.email, role: 'admin', banned: '0' }
    }

    assert_redirected_to admin_users_path
    assert @profesional.reload.admin?
  end

  test 'non-admin cannot access users index' do
    sign_in @profesional
    get admin_users_path
    assert_redirected_to root_path
  end
end
