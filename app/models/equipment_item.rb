# frozen_string_literal: true

class EquipmentItem < ApplicationRecord
  has_many :space_equipment_items, dependent: :destroy
  has_many :spaces, through: :space_equipment_items

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
end
