# frozen_string_literal: true

class ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking

  def create
    @review = @booking.build_review(review_params.merge(renter: current_user, box: @booking.box))
    if @review.save
      redirect_to @booking, notice: 'Gracias por tu reseña'
    else
      redirect_to @booking, alert: @review.errors.full_messages.join(', ')
    end
  end

  private

  def set_booking
    @booking = current_user.bookings.completed.find(params.expect(:booking_id))
  end

  def review_params
    params.expect(review: %i[rating body])
  end
end
