# frozen_string_literal: true

module LazyImageHelper
  VARIANT_LIMITS_DEFAULT = [1200, 800].freeze
  VARIANT_LIMITS_GRID = [640, 480].freeze
  VARIANT_LIMITS_LIGHTBOX = [800, 600].freeze
  VARIANT_LIMITS_GALLERY_GRID = [480, 640].freeze
  VARIANT_LIMITS_GALLERY_MAIN = [1200, 800].freeze
  VARIANT_LIMITS_GALLERY_THUMB = [320, 240].freeze

  MASONRY_ASPECT_CLASSES = %w[
    aspect-[4/5]
    aspect-[3/4]
    aspect-square
    aspect-[5/4]
    aspect-[4/3]
  ].freeze

  def masonry_aspect_class_for(seed)
    MASONRY_ASPECT_CLASSES[seed.to_i % MASONRY_ASPECT_CLASSES.size]
  end

  def lazy_variant_image(attachment, alt:, resize_to_limit: VARIANT_LIMITS_DEFAULT, eager: false, **locals)
    return unless attachment&.attached?

    url = url_for(attachment.variant(resize_to_limit: resize_to_limit))
    render partial: 'shared/lazy_variant_image', locals: { url: url, alt: alt, eager: eager, **locals }
  end

  def lazy_asset_image(source, alt:, **locals)
    url = asset_path(source)
    render partial: 'shared/lazy_variant_image', locals: { url: url, alt: alt, **locals }
  end

  def place_photo_lightbox_entries(photos, title)
    photos.map do |photo|
      alt = photo.caption.presence || title
      {
        url: url_for(photo.image.variant(resize_to_limit: VARIANT_LIMITS_LIGHTBOX)),
        alt: alt
      }
    end
  end
end
