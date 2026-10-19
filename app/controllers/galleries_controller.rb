# frozen_string_literal: true

class GalleriesController < ApplicationController
  def show
    @items = GalleryItem.items_for_tag_slug(params.expect(:tag))
    raise ActiveRecord::RecordNotFound if @items.empty?

    @tag_label = @items.first.tag_label
    @tag_slug = @items.first.tag_slug
    @tag_description = GalleryTag.description_for_label(@tag_label)
    @current_item = find_current_item(@items)
  end

  private

  def find_current_item(items)
    if params[:photo_id].present?
      items.find { |item| item.id == params[:photo_id].to_i } || items.first
    else
      items.first
    end
  end
end
