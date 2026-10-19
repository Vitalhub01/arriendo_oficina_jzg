# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @office = Office.first
    @spaces = Space.published_spaces.includes(space_photos: { image_attachment: :blob }).order(:title).limit(3)
    @home_min_hourly_price_cents = Space.home_min_hourly_price_cents
    @home_morning_block_price_cents = Space.home_min_morning_block_price_cents
    @home_afternoon_block_price_cents = Space.home_min_afternoon_block_price_cents
    @min_jornada_price_cents = Space.home_min_jornada_price_cents
    @testimonials = Testimonial.visible.includes(:profesional).order(created_at: :desc).limit(6)
    @faqs = Faq.where(visible: true).order(:position)
    @social_contacts = SocialContact.visible.ordered.with_attached_icon
    @gallery_groups = GalleryItem.grouped_by_tag(GalleryItem.visible.ordered.with_attached_image)
    @home_highlights = HomeHighlight.visible.ordered
  end
end
