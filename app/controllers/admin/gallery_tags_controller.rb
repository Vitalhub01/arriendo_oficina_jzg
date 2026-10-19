# frozen_string_literal: true

module Admin
  class GalleryTagsController < Admin::BaseController
    before_action :set_gallery_tag, only: %i[edit update]

    def index
      GalleryTag.sync_from_gallery_items!
      @gallery_tags = GalleryTag.ordered
      @photo_counts = GalleryItem.photo_counts_by_label
    end

    def edit; end

    def update
      if @gallery_tag.update(gallery_tag_params)
        redirect_to admin_gallery_tags_path, notice: 'Descripción actualizada'
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_gallery_tag
      @gallery_tag = GalleryTag.find(params.expect(:id))
    end

    def gallery_tag_params
      params.expect(gallery_tag: [:description])
    end
  end
end
