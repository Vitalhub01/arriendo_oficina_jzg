# frozen_string_literal: true

class AmenityTag < ApplicationRecord
  has_many :space_amenity_assignments, dependent: :destroy
  has_many :spaces, through: :space_amenity_assignments

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
end
