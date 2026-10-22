# frozen_string_literal: true

class GalleriesController < ApplicationController
  def frame
    @item = GalleryItem.visible.find(params.expect(:id))
    @frame_context = params[:frame].presence_in(%w[photo cover]) || 'cover'
    render layout: false
  end

  def show
    @item = GalleryItem.items_for_tag_slug(params.expect(:tag)).first
    raise ActiveRecord::RecordNotFound unless @item

    @tag_label = @item.tag_label
    @tag_slug = @item.tag_slug
    @tag_description = GalleryTag.description_for_label(@tag_label)
  end
end
