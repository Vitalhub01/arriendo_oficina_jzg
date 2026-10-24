# frozen_string_literal: true

class SpaceAmenityAssignment < ApplicationRecord
  belongs_to :space
  belongs_to :amenity_tag
end
