# frozen_string_literal: true

class GalleryItem < ApplicationRecord
  has_one_attached :image

  UNTAGGED_LABEL = 'General'

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
  after_commit :enqueue_variant_preprocessing, on: :create

  def enqueue_variant_preprocessing
    return unless image.attached?

    PreprocessGalleryItemVariantsJob.perform_later(id)
  end

  def self.grouped_by_tag(scope = visible.ordered)
    scope.group_by(&:tag_label).sort_by do |_label, items|
      items.map(&:position).min || 0
    end
  end

  def self.items_for_tag_slug(slug)
    visible.ordered.select { |item| item.tag_slug == slug.to_s }
  end

  def self.distinct_tag_labels
    pluck(:tag)
      .map { |tag| tag.presence || UNTAGGED_LABEL }
      .uniq
      .sort_by { |label| label.parameterize }
  end

  def self.photo_counts_by_label
    pluck(:tag).group_by { |tag| tag.presence || UNTAGGED_LABEL }.transform_values(&:count)
  end

  def tag_label
    tag.presence || UNTAGGED_LABEL
  end

  def tag_slug
    tag_label.parameterize
  end

  def display_alt
    alt_text.presence || tag.presence || 'Espacio VitalHub'
  end

  def masonry_aspect_class
    %w[aspect-[4/5] aspect-[3/4] aspect-square aspect-[5/4] aspect-[4/3]][id % 5]
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
