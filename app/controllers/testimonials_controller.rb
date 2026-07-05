# frozen_string_literal: true

class TestimonialsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking

  def create
    @testimonial = @booking.build_testimonial(
      testimonial_params.merge(
        profesional: current_user,
        space: @booking.space
      )
    )

    if @testimonial.save
      redirect_to @booking, notice: 'Gracias por tu testimonio'
    else
      redirect_to @booking, alert: @testimonial.errors.full_messages.join(', ')
    end
  end

  private

  def set_booking
    @booking = current_user.bookings.completed.find(params[:booking_id])
  end

  def testimonial_params
    params.expect(testimonial: %i[rating body])
  end
end
