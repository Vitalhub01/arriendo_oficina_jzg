# frozen_string_literal: true

module Admin
  class TestimonialsController < Admin::BaseController
    before_action :set_testimonial, only: %i[update]

    def index
      @pagy, @testimonials = pagy(
        Testimonial.includes(:space, :profesional).order(created_at: :desc)
      )
    end

    def update
      if @testimonial.update(testimonial_params)
        redirect_to admin_testimonials_path, notice: 'Testimonio actualizado'
      else
        redirect_to admin_testimonials_path, alert: @testimonial.errors.full_messages.join(', ')
      end
    end

    private

    def set_testimonial
      @testimonial = Testimonial.find(params.expect(:id))
    end

    def testimonial_params
      params.expect(testimonial: %i[visible rating body])
    end
  end
end
