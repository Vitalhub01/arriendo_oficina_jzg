# frozen_string_literal: true

class EquipmentItem < ApplicationRecord
  has_many :space_equipment_items, dependent: :destroy
  has_many :spaces, through: :space_equipment_items

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :price_per_hour_cents,
            numericality: { greater_than: 0, only_integer: true, allow_nil: true }

  before_validation :normalize_price_per_hour

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }
  scope :rentable, -> { where('price_per_hour_cents > 0') }

  def rentable?
    price_per_hour_cents.to_i.positive?
  end

  private

  def normalize_price_per_hour
    cents = price_per_hour_cents
    self.price_per_hour_cents = nil if cents.blank? || cents.to_i <= 0
  end
end
