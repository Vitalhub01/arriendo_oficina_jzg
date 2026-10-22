# frozen_string_literal: true

require 'test_helper'

class SpaceDisplayOrderTest < ActiveSupport::TestCase
  test 'ordered_for_display sorts by display_position' do
    first = spaces(:published_box)
    second = spaces(:draft_box)
    first.update_column(:display_position, 1)
    second.update_column(:display_position, 0)

    ids = Space.ordered_for_display.where(id: [first.id, second.id]).pluck(:id)
    assert_equal [second.id, first.id], ids
  end
end
