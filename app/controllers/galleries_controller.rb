# frozen_string_literal: true

class GalleriesController < ApplicationController
  MAIN_PHOTO_FRAME = 'gallery_main_photo'

  def frame
    @item = GalleryItem.visible.find(params.expect(:id))
    @frame_context = params[:frame].presence_in(%w[photo cover]) || 'cover'
    render layout: false
  end

  def show
    load_gallery_tag_page!
    return unless turbo_frame_request?

    render partial: 'galleries/main_photo_frame', layout: false
  end

  private

  def load_gallery_tag_page!
    @items = GalleryItem.items_for_tag_slug(params.expect(:tag)).to_a
    raise ActiveRecord::RecordNotFound if @items.empty?

    @tag_label = @items.first.tag_label
    @tag_slug = @items.first.tag_slug
    @tag_description = GalleryTag.description_for_label(@tag_label)

    @highlight_item = if params[:photo_id].present?
                        @items.find { |item| item.id == params[:photo_id].to_i }
                      end
    @highlight_item ||= @items.first
    @item = @highlight_item
    @index = @items.index(@item)
    @prev_item = @index.positive? ? @items[@index - 1] : nil
    @next_item = @index && @index < @items.size - 1 ? @items[@index + 1] : nil
  end

  def turbo_frame_request?
    request.headers['Turbo-Frame'] == MAIN_PHOTO_FRAME
  end
end
