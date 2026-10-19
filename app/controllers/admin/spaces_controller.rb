# frozen_string_literal: true

module Admin
  class SpacesController < Admin::BaseController
    before_action :set_space, only: %i[show edit update destroy]

    def index
      @spaces = Space.includes(:office, space_photos: { image_attachment: :blob }).order(created_at: :desc)
    end

    def show; end

    def new
      @space = Space.new(office: Office.first, price_per_hour_cents: 6_000)
      @pricing_values = default_pricing_values
    end

    def edit
      @pricing_values = @space.admin_pricing_values
    end

    def create
      @space = Space.new(space_params)
      @pricing_values = pricing_values_from_request
      assign_hourly_price_from_pricing!

      if save_space_with_pricing!
        redirect_to edit_admin_space_path(@space), notice: 'Espacio creado'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      @space.assign_attributes(space_params)
      @pricing_values = pricing_values_from_request

      if save_space_with_pricing!
        redirect_to edit_admin_space_path(@space), notice: 'Espacio actualizado'
      else
        @pricing_values = pricing_values_from_request
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @space.destroy
      redirect_to admin_spaces_path, notice: 'Espacio eliminado'
    end

    private

    def set_space
      @space = Space.find(params.expect(:id))
    end

    def space_params
      raw = params.require(:space).permit(
        :title, :description, :address, :commune, :city, :office_id,
        :latitude, :longitude, :box_type, :price_per_hour_cents,
        :slot_duration_minutes, :minimum_slots, :reschedule_notice_hours,
        :minimum_hours, :status, :capacity, :dimensions,
        :terms_and_conditions,
        amenities: {}, equipment: []
      )

      terms = raw[:terms_and_conditions]
      raw = raw.except(:terms_and_conditions) if terms.blank?

      raw
    end

    def pricing_params
      return {} unless params[:pricing]

      params.expect(
        pricing: %i[
          morning_hourly_price_cents afternoon_hourly_price_cents
          morning_block_price_cents afternoon_block_price_cents
          jornada_price_cents
        ]
      )
    end

    def save_space_with_pricing!
      success = false
      ActiveRecord::Base.transaction do
        unless @space.save
          raise ActiveRecord::Rollback
        end
        unless apply_pricing!
          raise ActiveRecord::Rollback
        end
        success = true
      end
      success
    end

    def assign_hourly_price_from_pricing!
      cents = @pricing_values[:morning_hourly_price_cents]
      @space.price_per_hour_cents = cents if cents.present?
    end

    def pricing_values_from_request
      return default_pricing_values if pricing_params.blank?

      default_pricing_values.merge(pricing_params.to_h.symbolize_keys)
    end

    def apply_pricing!
      result = ::Spaces::UpsertPricing.new(space: @space, params: @pricing_values).call
      return true if result.success?

      @pricing_errors = result.errors
      @space.errors.add(:base, result.errors.join(', '))
      false
    end

    def default_pricing_values
      {
        morning_hourly_price_cents: 6_000,
        afternoon_hourly_price_cents: 6_000,
        morning_block_price_cents: 25_000,
        afternoon_block_price_cents: 28_000,
        jornada_price_cents: 48_000
      }
    end
  end
end
