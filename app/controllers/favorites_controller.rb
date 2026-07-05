# frozen_string_literal: true

class FavoritesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_box

  def create
    current_user.favorites.find_or_create_by!(box: @box)
    redirect_back_or_to(@box, notice: 'Agregado a favoritos')
  end

  def destroy
    current_user.favorites.where(box: @box).destroy_all
    redirect_back_or_to(@box, notice: 'Eliminado de favoritos')
  end

  private

  def set_box
    @box = Box.published_boxes.find(params.expect(:box_id))
  end
end
