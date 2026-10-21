# frozen_string_literal: true

class SpacePhoto < ApplicationRecord
  belongs_to :space, class_name: 'Space', foreign_key: :box_id, inverse_of: :space_photos

  has_one_attached :image

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :image_must_be_attached, unless: :new_record?

  scope :ordered, -> { order(:position, :id) }

  before_validation :assign_next_position, on: :create
  after_commit :enqueue_variant_preprocessing, on: :create

  def enqueue_variant_preprocessing
    return unless image.attached?

    PreprocessSpacePhotoVariantsJob.perform_later(id)
  end

  private

  def assign_next_position
    return if position.positive?
    return unless space

    max = space.space_photos.where.not(id: id).maximum(:position)
    self.position = (max || -1) + 1
  end

  def image_must_be_attached
    return if image.attached?

    errors.add(:image, 'es obligatoria')
  end
end
