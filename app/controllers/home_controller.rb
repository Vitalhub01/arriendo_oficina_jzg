# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @office = Office.first
    @spaces = Space.published_spaces.includes(photos_attachments: :blob).order(:title).limit(3)
    @jornadas = JornadaDefinition.active.order(:position)
    @testimonials = Testimonial.visible.includes(:profesional).order(created_at: :desc).limit(6)
    @faqs = Faq.where(visible: true).order(:position)
  end
end
