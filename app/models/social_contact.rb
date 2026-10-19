# frozen_string_literal: true

class SocialContact < ApplicationRecord
  has_one_attached :icon

  validates :name, :url, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: 'debe ser una URL válida (http o https)' }
  validate :icon_must_be_attached
  validate :icon_must_be_png

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(:position, :created_at) }

  def display_handle
    username.presence || name
  end

  private

  def icon_must_be_attached
    return if icon.attached?

    errors.add(:icon, 'es obligatorio')
  end

  def icon_must_be_png
    return unless icon.attached? && icon.blob.present?
    return if icon.blob.content_type == 'image/png'

    errors.add(:icon, 'debe ser un archivo PNG')
  end
end
