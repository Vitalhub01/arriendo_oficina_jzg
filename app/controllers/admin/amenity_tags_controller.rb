# frozen_string_literal: true

module Admin
  class AmenityTagsController < Admin::BaseController
    before_action :set_amenity_tag, only: %i[edit update destroy]

    def index
      @amenity_tags = AmenityTag.ordered
    end

    def new
      @amenity_tag = AmenityTag.new
    end

    def edit; end

    def create
      @amenity_tag = AmenityTag.new(amenity_tag_params)

      if @amenity_tag.save
        redirect_to admin_amenity_tags_path, notice: 'Etiqueta creada'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @amenity_tag.update(amenity_tag_params)
        redirect_to admin_amenity_tags_path, notice: 'Etiqueta actualizada'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @amenity_tag.destroy
      redirect_to admin_amenity_tags_path, notice: 'Etiqueta eliminada'
    end

    private

    def set_amenity_tag
      @amenity_tag = AmenityTag.find(params.expect(:id))
    end

    def amenity_tag_params
      params.expect(amenity_tag: %i[name position active])
    end
  end
end
