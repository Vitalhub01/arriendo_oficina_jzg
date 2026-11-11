# frozen_string_literal: true

require 'test_helper'

class PasswordResetRequestTest < ActiveSupport::TestCase
  setup do
    @user = users(:profesional)
    @admin = users(:admin)
  end

  test 'resolve! marks request as resolved' do
    req = PasswordResetRequest.create!(email: @user.email, user: @user, status: :pending)

    req.resolve!(by: @admin)

    assert req.resolved?
    assert req.resolved_at.present?
    assert_equal @admin, req.resolved_by
  end
end
