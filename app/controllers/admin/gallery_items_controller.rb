# frozen_string_literal: true

module Admin
  class GalleryItemsController < Admin::BaseController
    def index
      @gallery_items = GalleryItem.ordered.with_attached_image
    end

    def create
      unless params[:image].present?
        return render json: { errors: ['Debes elegir una imagen'] }, status: :unprocessable_content
      end

      @gallery_item = GalleryItem.new(gallery_item_update_params)
      @gallery_item.image.attach(params[:image])

      if @gallery_item.save
        render json: { html: render_item(@gallery_item) }, status: :created
      else
        render json: { errors: @gallery_item.errors.full_messages }, status: :unprocessable_content
      end
    end

    def update
      @gallery_item = GalleryItem.find(params.expect(:id))

      if @gallery_item.update(gallery_item_update_params)
        head :no_content
      else
        render json: { errors: @gallery_item.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      @gallery_item = GalleryItem.find(params.expect(:id))
      @gallery_item.destroy
      head :no_content
    end

    def reorder
      Array(params[:order]).each_with_index do |id, index|
        GalleryItem.where(id: id).update_all(position: index)
      end
      head :no_content
    end

    private

    def gallery_item_update_params
      params.fetch(:gallery_item, {}).permit(:tag, :alt_text, :visible)
    end

    def render_item(item)
      render_to_string(
        partial: 'admin/gallery_items/item',
        locals: { item: item },
        formats: [:html]
      )
    end
  end
end
