# frozen_string_literal: true

class HomeIndexQuery
  def self.call
    new.call
  end

  def call
    {
      office: Office.first,
      spaces: featured_spaces,
      home_min_hourly_price_cents: pricing[:min_hourly_cents],
      home_morning_block_price_cents: pricing[:min_morning_block_cents],
      home_afternoon_block_price_cents: pricing[:min_afternoon_block_cents],
      min_jornada_price_cents: pricing[:min_jornada_cents],
      testimonials: testimonials,
      faqs: faqs,
      social_contacts: social_contacts,
      gallery_groups: gallery_groups,
      home_highlights: home_highlights
    }
  end

  private

  def featured_spaces
    Space.published_spaces
         .includes(space_photos: { image_attachment: :blob })
         .ordered_for_display
         .limit(3)
  end

  def pricing
    @pricing ||= Space.home_pricing_snapshot
  end

  def testimonials
    Testimonial.visible.includes(:profesional).order(created_at: :desc).limit(6)
  end

  def faqs
    Faq.where(visible: true).order(:position)
  end

  def social_contacts
    SocialContact.visible.ordered.with_attached_icon
  end

  def gallery_groups
    GalleryItem.home_gallery_groups
  end

  def home_highlights
    HomeHighlight.visible.ordered
  end

end
