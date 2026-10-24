# frozen_string_literal: true

module Admin
  class EquipmentItemsController < Admin::BaseController
    before_action :set_equipment_item, only: %i[edit update destroy]

    def index
      @equipment_items = EquipmentItem.ordered
    end

    def new
      @equipment_item = EquipmentItem.new
    end

    def edit; end

    def create
      @equipment_item = EquipmentItem.new(equipment_item_params)

      if @equipment_item.save
        redirect_to admin_equipment_items_path, notice: 'Implemento creado'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @equipment_item.update(equipment_item_params)
        redirect_to admin_equipment_items_path, notice: 'Implemento actualizado'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @equipment_item.destroy
      redirect_to admin_equipment_items_path, notice: 'Implemento eliminado'
    end

    private

    def set_equipment_item
      @equipment_item = EquipmentItem.find(params.expect(:id))
    end

    def equipment_item_params
      params.expect(equipment_item: %i[name position active price_per_hour_cents])
    end
  end
end
