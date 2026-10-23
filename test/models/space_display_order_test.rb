# frozen_string_literal: true

require 'test_helper'

class SpaceDisplayOrderTest < ActiveSupport::TestCase
  test 'ordered_for_display sorts by display_position' do
    first = boxes(:published_box)
    second = boxes(:draft_box)
    first.update_column(:display_position, 1)
    second.update_column(:display_position, 0)

    ids = Space.ordered_for_display.where(id: [first.id, second.id]).pluck(:id)
    assert_equal [second.id, first.id], ids
  end
end
