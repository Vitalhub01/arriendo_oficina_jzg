# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'can_book allows profesional without professional profile' do
    user = users(:profesional)
    user.professional_profile&.destroy
    user.reload

    assert_nil user.professional_profile
    assert user.can_book?
  end

  test 'can_book allows pending validation status' do
    user = users(:renter)
    user.professional_profile.update!(validation_status: :pending)

    assert user.can_book?
  end

  test 'can_book blocks rejected profile' do
    user = users(:renter)
    user.professional_profile.update!(validation_status: :rejected)

    assert_not user.can_book?
  end

  test 'can_book blocks banned users' do
    user = users(:renter)
    user.update!(banned_at: Time.current)

    assert_not user.can_book?
  end
end
