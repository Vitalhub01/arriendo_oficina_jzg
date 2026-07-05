# frozen_string_literal: true

module Admin
  class BoxesController < Admin::BaseController
    def index
      @boxes = Box.includes(:owner).order(created_at: :desc)
    end

    def update
      @box = Box.find(params.expect(:id))
      if @box.update(status: params[:box][:status])
        redirect_to admin_boxes_path, notice: 'Estado actualizado'
      else
        redirect_to admin_boxes_path, alert: 'No se pudo actualizar'
      end
    end
  end
end
