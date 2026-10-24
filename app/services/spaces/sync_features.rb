# frozen_string_literal: true

module Spaces
  class SyncFeatures
    def initialize(space:, equipment_item_ids:, amenity_tag_ids:)
      @space = space
      @equipment_item_ids = Array(equipment_item_ids).map(&:to_i).reject(&:zero?).uniq
      @amenity_tag_ids = Array(amenity_tag_ids).map(&:to_i).reject(&:zero?).uniq
    end

    def call
      space.equipment_item_ids = equipment_item_ids
      space.amenity_tag_ids = amenity_tag_ids
      true
    end

    private

    attr_reader :space, :equipment_item_ids, :amenity_tag_ids
  end
end
