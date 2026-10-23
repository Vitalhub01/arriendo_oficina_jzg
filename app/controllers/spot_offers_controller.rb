# frozen_string_literal: true

class SpotOffersController < ApplicationController
  before_action :set_spot_offer

  def show
    @occurrences = SpotOffers::BuildOccurrences.new(
      space: @spot_offer.space,
      starts_on: @spot_offer.starts_on,
      ends_on: @spot_offer.ends_on,
      daily_start_time: @spot_offer.daily_start_time,
      daily_end_time: @spot_offer.daily_end_time
    ).call
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
