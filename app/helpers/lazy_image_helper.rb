# frozen_string_literal: true

module LazyImageHelper
  VARIANT_LIMITS_DEFAULT = [1200, 800].freeze

  def lazy_variant_image(attachment, alt:, resize_to_limit: VARIANT_LIMITS_DEFAULT, **locals)
    return unless attachment&.attached?

    url = url_for(attachment.variant(resize_to_limit: resize_to_limit))
    render partial: 'shared/lazy_variant_image', locals: { url: url, alt: alt, **locals }
  end

  def lazy_asset_image(source, alt:, **locals)
    url = asset_path(source)
    render partial: 'shared/lazy_variant_image', locals: { url: url, alt: alt, **locals }
  end
end
