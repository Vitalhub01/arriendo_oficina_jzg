# frozen_string_literal: true

module Admin
  class TestimonialsController < Admin::BaseController
    before_action :set_testimonial, only: %i[edit update destroy]

    def index
      @pagy, @testimonials = pagy(
        Testimonial.includes(:space, :profesional).order(created_at: :desc)
      )
    end

    def new
      @testimonial = Testimonial.new(visible: true)
    end

    def edit; end

    def create
      @testimonial = Testimonial.new(admin_testimonial_params)

      if @testimonial.save
        redirect_to admin_testimonials_path, notice: 'Testimonio creado'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @testimonial.update(admin_testimonial_params)
        redirect_to admin_testimonials_path, notice: 'Testimonio actualizado'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @testimonial.destroy
      redirect_to admin_testimonials_path, notice: 'Testimonio eliminado'
    end

    private

    def set_testimonial
      @testimonial = Testimonial.find(params.expect(:id))
    end

    def admin_testimonial_params
      params.expect(testimonial: %i[author_name body rating visible])
    end
  end
end
