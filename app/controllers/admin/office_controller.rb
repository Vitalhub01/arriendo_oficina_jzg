# frozen_string_literal: true

module Admin
  class OfficeController < Admin::BaseController
    before_action :set_office

    def edit; end

    def update
      if @office.update(office_params)
        redirect_to edit_admin_office_path, notice: 'Oficina actualizada'
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_office
      @office = Office.first || Office.create!(
        name: 'Oficina principal',
        address: 'Por configurar',
        commune: 'Santiago',
        city: 'Santiago'
      )
    end

    def office_params
      params.expect(
        office: [:name, :description, :address, :commune, :city, :latitude, :longitude, { photos: [] }]
      )
    end
  end
end
