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
      @space_for_form = space_for_inline_form

      if @equipment_item.save
        assign_to_space_from_form!(@space_for_form, @equipment_item)
        respond_to_inline_create(notice: 'Implemento creado')
      else
        respond_to_inline_create_failure
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

    def inline_create?
      params[:inline].present?
    end

    def space_for_inline_form
      return Space.new if params[:from_space_id].blank?

      Space.find_by(id: params[:from_space_id]) || Space.new
    end

    def assign_to_space_from_form!(space, item)
      return unless space.persisted?

      space.equipment_items << item unless space.equipment_item_ids.include?(item.id)
      space.reload
    end

    def respond_to_inline_create(notice:)
      if inline_create?
        render :create, formats: :turbo_stream
      else
        redirect_to admin_equipment_items_path, notice: notice
      end
    end

    def respond_to_inline_create_failure
      if inline_create?
        render turbo_stream: turbo_stream.replace(
          'equipment_item_quick_add',
          partial: 'quick_add_form',
          locals: { equipment_item: @equipment_item, space: @space_for_form }
        ), status: :unprocessable_content
      else
        render :new, status: :unprocessable_content
      end
    end
  end
end
