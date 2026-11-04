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

  test 'admin generates shareable password reset link' do
    sign_in @admin
    @profesional.update!(reset_password_token: nil, reset_password_sent_at: nil)

    get password_reset_link_admin_user_path(@profesional)
    assert_response :success
    assert_match %r{/users/password/edit\?reset_password_token=}, response.body
    assert @profesional.reload.reset_password_token.present?

    token = response.body[%r{reset_password_token=([^"&\s]+)}, 1]
    sign_out @admin
    get edit_user_password_path(reset_password_token: token)
    assert_response :success
  end
end
