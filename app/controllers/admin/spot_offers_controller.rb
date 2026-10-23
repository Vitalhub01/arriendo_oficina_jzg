# frozen_string_literal: true

module Admin
  class SpotOffersController < Admin::BaseController
    before_action :set_spot_offer, only: %i[show]

    def index
      @spot_offers = SpotOffer.includes(:space, :created_by).recent
    end

    def new
      @spot_offer = SpotOffer.new(
        starts_on: Date.current,
        ends_on: Date.current.end_of_month,
        daily_start_time: SpaceBlockPeriods.time_on(SpaceBlockPeriods::MORNING[:start]),
        daily_end_time: SpaceBlockPeriods.time_on(SpaceBlockPeriods::MORNING[:end])
      )
      @spaces = Space.order(:title)
      @preview_count = nil
    end

    def create
      @spot_offer = SpotOffer.new(spot_offer_params)
      @spot_offer.created_by = current_user
      occurrences = preview_occurrences(@spot_offer)
      @spot_offer.occurrence_count = occurrences.size

      if occurrences.empty?
        @spaces = Space.order(:title)
        @preview_count = 0
        @spot_offer.errors.add(:base, 'No hay fechas disponibles con ese rango y horario')
        render :new, status: :unprocessable_content
      elsif @spot_offer.save
        redirect_to admin_spot_offer_path(@spot_offer), notice: 'Tarifa spot creada'
      else
        @spaces = Space.order(:title)
        @preview_count = occurrences.size
        render :new, status: :unprocessable_content
      end
    end

    def show; end

    private

    def set_spot_offer
      @spot_offer = SpotOffer.find(params.expect(:id))
    end

    def spot_offer_params
      params.expect(
        spot_offer: %i[
          space_id title total_price_cents starts_on ends_on daily_start_time daily_end_time
        ]
      )
    end

    def preview_occurrences(offer)
      return [] unless offer.space && offer.starts_on && offer.ends_on

      SpotOffers::BuildOccurrences.new(
        space: offer.space,
        starts_on: offer.starts_on,
        ends_on: offer.ends_on,
        daily_start_time: offer.daily_start_time,
        daily_end_time: offer.daily_end_time
      ).call
    end
  end
end
