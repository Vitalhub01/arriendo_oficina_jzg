# frozen_string_literal: true

module Admin
  module Spaces
    class PhotosController < Admin::BaseController
      before_action :set_space

      def create
        unless params[:image].present?
          return render json: { errors: ['Debes elegir una imagen'] }, status: :unprocessable_content
        end

        @photo = @space.space_photos.build
        @photo.image.attach(params[:image])

        if @photo.save
          render json: { html: render_item(@photo) }, status: :created
        else
          render json: { errors: @photo.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        @photo = @space.space_photos.find(params.expect(:id))

        if @photo.update(photo_update_params)
          head :no_content
        else
          render json: { errors: @photo.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        @photo = @space.space_photos.find(params.expect(:id))
        @photo.destroy
        head :no_content
      end

      def reorder
        Array(params[:order]).each_with_index do |id, index|
          @space.space_photos.where(id: id).update_all(position: index)
        end
        head :no_content
      end

      private

      def set_space
        @space = Space.find(params.expect(:space_id))
      end

      def photo_update_params
        params.permit(:caption)
      end

      def render_item(photo)
        render_to_string(
          partial: 'admin/spaces/photos/item',
          locals: { photo: photo, space: @space },
          formats: [:html]
        )
      end
    end
  end
end
