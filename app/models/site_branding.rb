# frozen_string_literal: true

class SiteBranding < ApplicationRecord
  has_one_attached :logo
  has_one_attached :hero_image

  ALLOWED_LOGO_TYPES = %w[image/png image/jpeg image/webp].freeze
  ALLOWED_HERO_TYPES = %w[image/png image/jpeg image/webp].freeze

  validate :logo_content_type, if: -> { logo.attached? }
  validate :hero_image_content_type, if: -> { hero_image.attached? }

  def self.current
    with_attached_logo.with_attached_hero_image.first || create!
  end

  after_commit :normalize_branding_images

  def normalize_branding_images
    ImageUploadNormalizer.normalize!(logo) if logo.attached?
    ImageUploadNormalizer.normalize!(hero_image) if hero_image.attached?
  end

  private

  def logo_content_type
    return if ALLOWED_LOGO_TYPES.include?(logo.blob.content_type)

    errors.add(:logo, 'debe ser PNG, JPG o WebP')
  end

  def hero_image_content_type
    return if ALLOWED_HERO_TYPES.include?(hero_image.blob.content_type)

    errors.add(:hero_image, 'debe ser PNG, JPG o WebP')
  end
end
