# frozen_string_literal: true

class HomeHighlight < ApplicationRecord
  CITY_PLACEHOLDER = '{ciudad}'

  validates :title, :description, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :icon_key, inclusion: { in: ->(_) { HomeHighlightIcons.keys } }

  before_validation :normalize_icon_key

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :created_at) }

  def rendered_description(office_city: nil)
    city = office_city.presence || 'Chile'
    description.gsub(CITY_PLACEHOLDER, city)
  end

  private

  def normalize_icon_key
    self.icon_key = HomeHighlightIcons::DEFAULT_KEY if icon_key.blank?
    self.icon_key = HomeHighlightIcons::DEFAULT_KEY unless HomeHighlightIcons.valid_key?(icon_key)
  end
end
