# frozen_string_literal: true

module Admin
  class SpacesController < Admin::BaseController
    before_action :set_space, only: %i[show edit update destroy]

    def index
      @spaces = Space.includes(:office).order(created_at: :desc)
    end

    def show; end

    def new
      @space = Space.new(office: Office.first)
    end

    def edit; end

    def create
      @space = Space.new(space_params)
      geocode_if_needed(@space)

      if @space.save
        redirect_to admin_space_path(@space), notice: 'Espacio creado'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      @space.assign_attributes(space_params)
      geocode_if_needed(@space)

      if @space.save
        redirect_to admin_space_path(@space), notice: 'Espacio actualizado'
      else
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
      params.expect(
        space: [:title, :description, :address, :commune, :city, :office_id,
                :latitude, :longitude, :box_type, :price_per_hour_cents,
                :slot_duration_minutes, :minimum_slots,
                :minimum_hours, :status, :capacity, :dimensions,
                { amenities: {}, equipment: [], photos: [] }]
      )
    end

    def geocode_if_needed(space)
      return if space.latitude.present? && space.longitude.present?

      coords = GeocoderService.geocode(space.address, city: space.city, commune: space.commune)
      return unless coords

      space.latitude = coords[:latitude]
      space.longitude = coords[:longitude]
    end
  end
end
