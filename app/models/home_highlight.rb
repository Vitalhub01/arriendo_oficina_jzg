# frozen_string_literal: true

class HomeHighlight < ApplicationRecord
  CITY_PLACEHOLDER = '{ciudad}'

  validates :title, :description, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :created_at) }

  def rendered_description(office_city: nil)
    city = office_city.presence || 'Chile'
    description.gsub(CITY_PLACEHOLDER, city)
  end
end
