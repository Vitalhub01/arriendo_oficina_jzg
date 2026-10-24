# frozen_string_literal: true

require 'test_helper'

module Spaces
  class SyncFeaturesTest < ActiveSupport::TestCase
    test 'assigns equipment and amenity tags to space' do
      space = boxes(:published_box)
      equipment = equipment_items(:wifi_equipment)
      tag = amenity_tags(:bathroom_tag)

      SyncFeatures.new(
        space: space,
        equipment_item_ids: [equipment.id],
        amenity_tag_ids: [tag.id]
      ).call

      assert_equal [equipment.id], space.equipment_item_ids.sort
      assert_includes space.amenity_tag_ids, tag.id
    end
  end
end
