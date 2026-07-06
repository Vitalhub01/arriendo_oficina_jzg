# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @office = Office.first
    @spaces = Space.published_spaces.includes(photos_attachments: :blob).order(:title).limit(3)
    @min_slot_price = Space.published_spaces.map(&:default_price_per_slot_cents).min
    @full_day_rate = JornadaDefinition.active
                                      .where(office_id: @office&.id, space_id: nil)
                                      .order(:position)
                                      .first
    @testimonials = Testimonial.visible.includes(:profesional).order(created_at: :desc).limit(6)
    @faqs = Faq.where(visible: true).order(:position)
  end
end
