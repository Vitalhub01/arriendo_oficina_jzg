# frozen_string_literal: true

# Generates Active Storage variants ahead of time so the web process does not
# resize images on first page view (avoids memory spikes on small hosts).
#
# Keep limits in sync with image_tag ... variant(resize_to_limit: ...) in views.
class ImageVariantPreprocessor
  SPACE_PHOTO_LIMITS = [
    [1200, 800], # spaces/show, boxes/show — hero
    [640, 480],  # spaces/show, boxes/show — grid
    [800, 1000], # shared/_space_card
    [800, 600],  # shared/_box_card, home/_gallery (cover)
    [96, 72],    # admin/spaces/index
    [320, 240]   # admin/spaces/photos/_item
  ].freeze

  GALLERY_ITEM_LIMITS = [
    [1200, 800],  # galleries/show — main photo
    [480, 640],   # galleries/show — masonry grid
    [320, 240],   # admin/gallery_items/_item, gallery thumbs
    [800, 600]    # home/_gallery (cover)
  ].freeze

  def self.preprocess!(attachment, limits_list)
    return unless attachment.attached?

    limits_list.each do |limits|
      attachment.variant(resize_to_limit: limits).processed
    end
  end
end
