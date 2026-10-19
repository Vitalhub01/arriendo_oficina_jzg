# frozen_string_literal: true

class UserTestimonialsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_booking_history!

  def new
    @testimonial = current_user.general_testimonial || Testimonial.new
  end

  def create
    if current_user.general_testimonial.present?
      redirect_to new_user_testimonial_path, alert: 'Ya enviaste un comentario.'
      return
    end

    @testimonial = current_user.testimonials.build(user_testimonial_params.merge(visible: false))

    if @testimonial.save
      redirect_to new_user_testimonial_path, notice: 'Gracias por tu comentario. Lo revisaremos antes de publicarlo en el sitio.'
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def require_booking_history!
    return if current_user.bookings.exists?

    redirect_to root_path, alert: 'Solo quienes han reservado pueden dejar un comentario.'
  end

  def user_testimonial_params
    params.expect(testimonial: %i[body rating])
  end
end
