# frozen_string_literal: true

require 'test_helper'

class PasswordResetRequestsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @profesional = users(:profesional)
  end

  test 'login shows forgot password link' do
    get new_user_session_path
    assert_response :success
    assert_match '¿Olvidaste tu contraseña?', response.body
  end

  test 'user requests password reset without sending email' do
    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      assert_difference 'PasswordResetRequest.count', 1 do
        post user_password_path, params: { user: { email: @profesional.email } }
      end
    end

    assert_redirected_to password_request_sent_path
    follow_redirect!
    assert_match 'Solicitud recibida', response.body
    assert_match 'te contactaremos a la brevedad', response.body

    request = PasswordResetRequest.last
    assert_equal @profesional.email, request.email
    assert_equal @profesional, request.user
    assert request.pending?
  end

  test 'repeated requests within 24 hours reuse the same record' do
    assert_difference 'PasswordResetRequest.count', 1 do
      post user_password_path, params: { user: { email: @profesional.email } }
      post user_password_path, params: { user: { email: @profesional.email } }
    end
  end

  test 'request with unknown email still succeeds without revealing account' do
    assert_difference 'PasswordResetRequest.count', 1 do
      post user_password_path, params: { user: { email: 'desconocido@example.com' } }
    end

    assert_redirected_to password_request_sent_path
    assert_nil PasswordResetRequest.last.user
  end

  test 'admin sees pending requests on dashboard' do
    PasswordResetRequest.create!(email: @profesional.email, user: @profesional, status: :pending)

    sign_in @admin
    get admin_root_path
    assert_response :success
    assert_match 'recuperación de contraseña', response.body
  end

  test 'admin lists and resolves password reset request' do
    req = PasswordResetRequest.create!(email: @profesional.email, user: @profesional, status: :pending)

    sign_in @admin
    get admin_password_reset_requests_path
    assert_response :success
    assert_match @profesional.email, response.body

    patch admin_password_reset_request_path(req), params: { resolve: true }
    assert_redirected_to admin_password_reset_requests_path

    req.reload
    assert req.resolved?
    assert_equal @admin, req.resolved_by
  end

  test 'non-admin cannot access password reset requests' do
    sign_in @profesional
    get admin_password_reset_requests_path
    assert_redirected_to root_path
  end
end
