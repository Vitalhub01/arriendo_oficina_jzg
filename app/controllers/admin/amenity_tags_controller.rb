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
      @space_for_form = space_for_inline_form

      if @amenity_tag.save
        assign_to_space_from_form!(@space_for_form, @amenity_tag)
        respond_to_inline_create(notice: 'Etiqueta creada')
      else
        respond_to_inline_create_failure
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

    def inline_create?
      params[:inline].present?
    end

    def space_for_inline_form
      return Space.new if params[:from_space_id].blank?

      Space.find_by(id: params[:from_space_id]) || Space.new
    end

    def assign_to_space_from_form!(space, tag)
      return unless space.persisted?

      space.amenity_tags << tag unless space.amenity_tag_ids.include?(tag.id)
      space.reload
    end

    def respond_to_inline_create(notice:)
      if inline_create?
        render :create, formats: :turbo_stream
      else
        redirect_to admin_amenity_tags_path, notice: notice
      end
    end

    def respond_to_inline_create_failure
      if inline_create?
        render turbo_stream: turbo_stream.replace(
          'amenity_tag_quick_add',
          partial: 'quick_add_form',
          locals: { amenity_tag: @amenity_tag, space: @space_for_form }
        ), status: :unprocessable_content
      else
        render :new, status: :unprocessable_content
      end
    end
  end
end
