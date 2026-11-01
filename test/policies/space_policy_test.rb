# frozen_string_literal: true

require 'test_helper'

class SpacePolicyTest < ActiveSupport::TestCase
  test 'checkout is deprecated and denied for everyone' do
    space = boxes(:published_box)
    user = users(:renter)
    admin = users(:admin)

    assert_not SpacePolicy.new(nil, space).checkout?
    assert_not SpacePolicy.new(user, space).checkout?
    assert_not SpacePolicy.new(admin, space).checkout?
  end
end
