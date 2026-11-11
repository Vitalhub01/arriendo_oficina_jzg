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

  test 'clusters requests from same email within 24 hours' do
    older = PasswordResetRequest.create!(
      email: @user.email,
      user: @user,
      status: :pending,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago
    )
    newer = PasswordResetRequest.create!(
      email: @user.email,
      user: @user,
      status: :pending,
      created_at: 30.minutes.ago,
      updated_at: 30.minutes.ago
    )

    groups = PasswordResetRequest.grouped_day_windows([older, newer])
    assert_equal 1, groups.size
    assert_equal 2, groups.first.count
  end

  test 'splits requests from same email when gap exceeds 24 hours' do
    old = PasswordResetRequest.create!(
      email: @user.email,
      user: @user,
      status: :resolved,
      created_at: 3.days.ago,
      updated_at: 3.days.ago
    )
    recent = PasswordResetRequest.create!(
      email: @user.email,
      user: @user,
      status: :pending,
      created_at: 1.hour.ago,
      updated_at: 1.hour.ago
    )

    groups = PasswordResetRequest.grouped_day_windows([old, recent])
    assert_equal 2, groups.size
  end

  test 'resolve! closes every pending request in the same day window cluster' do
    first = PasswordResetRequest.create!(
      email: @user.email,
      user: @user,
      status: :pending,
      created_at: 2.hours.ago,
      updated_at: 2.hours.ago
    )
    second = PasswordResetRequest.create!(
      email: @user.email,
      user: @user,
      status: :pending,
      created_at: 1.hour.ago,
      updated_at: 1.hour.ago
    )

    first.resolve!(by: @admin)

    assert first.reload.resolved?
    assert second.reload.resolved?
  end
end
