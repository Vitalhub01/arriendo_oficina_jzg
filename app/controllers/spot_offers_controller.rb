# frozen_string_literal: true

class SpotOffersController < ApplicationController
  before_action :set_spot_offer

  def show
    @occurrences = @spot_offer.build_occurrences
  end

  def checkout
    authenticate_user!
    return redirect_to spot_offer_path(@spot_offer), alert: 'Inicia sesión para pagar' unless user_signed_in?
    return redirect_to spot_offer_path(@spot_offer), alert: 'Esta oferta ya no está disponible' unless @spot_offer.active?

    result = SpotOffers::Checkout.new(spot_offer: @spot_offer, profesional: current_user).call
    if result.success? && result.init_point.present?
      redirect_to result.init_point, allow_other_host: true
    else
      redirect_to spot_offer_path(@spot_offer), alert: result.error || 'No se pudo iniciar el pago'
    end
  end

  private

  def set_spot_offer
    @spot_offer = SpotOffer.find_by!(token: params.expect(:token))
  end
end
