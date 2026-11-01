# frozen_string_literal: true

module Admin
  module Bookings
    class SpotPackagesController < Admin::BaseController
      before_action :set_spot_offer, only: %i[show update]

      def index
        scope = SpotOffer.with_reservations.includes(:space, :profesional, :payment, :bookings).recent
        @pagy, @spot_offers = pagy(scope)
      end

      def show
        @bookings = @spot_offer.bookings.includes(:space, :profesional).order(:start_at)
        @confirm = SpotOffers::ConfirmManually.new(spot_offer: @spot_offer, actor: current_user)
      end

      def update
        if params[:confirm_manually].present?
          result = SpotOffers::ConfirmManually.new(spot_offer: @spot_offer, actor: current_user).call
          flash_key = result.success? ? :notice : :alert
          flash[flash_key] = result.success? ? 'Paquete spot confirmado manualmente' : result.errors.join(', ')
        end

        redirect_to admin_spot_package_path(@spot_offer)
      end

      private

      def set_spot_offer
        @spot_offer = SpotOffer.find_by!(token: params.expect(:id))
      end
    end
  end
end
