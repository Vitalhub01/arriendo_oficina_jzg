# frozen_string_literal: true

class SpaceEquipmentItem < ApplicationRecord
  belongs_to :space
  belongs_to :equipment_item
end
