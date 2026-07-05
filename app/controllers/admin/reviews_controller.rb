# frozen_string_literal: true

module Admin
  class ReviewsController < Admin::BaseController
    def index
      @pagy, @reviews = pagy(Review.includes(:box, :renter).order(created_at: :desc))
    end

    def update
      @review = Review.find(params.expect(:id))
      @review.update!(visible: params[:review][:visible])
      redirect_to admin_reviews_path, notice: 'Reseña actualizada'
    end
  end
end
