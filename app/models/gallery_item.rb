# frozen_string_literal: true

class GalleryItem < ApplicationRecord
  has_one_attached :image

  TAG_SUGGESTIONS = [
    'Recepción',
    'Box clínico',
    'Sala común',
    'Exterior',
    'Pasillo',
    'Equipamiento'
  ].freeze

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :image_must_be_attached, unless: :new_record?

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :id) }

  before_validation :assign_next_position, on: :create

  def display_alt
    alt_text.presence || tag.presence || 'Espacio VitalHub'
  end

  private

  def assign_next_position
    return if position.positive?

    self.position = (GalleryItem.maximum(:position) || -1) + 1
  end

  def image_must_be_attached
    return if image.attached?

    errors.add(:image, 'es obligatoria')
  end
end
