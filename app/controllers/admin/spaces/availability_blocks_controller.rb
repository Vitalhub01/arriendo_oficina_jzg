# frozen_string_literal: true

module Admin
  module Spaces
    class AvailabilityBlocksController < Admin::BaseController
      before_action :set_space

      def index
        @blocks = @space.availability_blocks.where('end_at >= ?', Time.current.beginning_of_day).order(:start_at)
        @block = @space.availability_blocks.build
      end

      def create
        if block_full_day?
          @block = build_full_day_block
        else
          @block = @space.availability_blocks.build(block_params)
        end

        if @block.save
          redirect_to admin_space_availability_blocks_path(@space), notice: 'Bloqueo agregado'
        else
          @blocks = @space.availability_blocks.where('end_at >= ?', Time.current.beginning_of_day).order(:start_at)
          render :index, status: :unprocessable_content
        end
      end

      def destroy
        @space.availability_blocks.find(params.expect(:id)).destroy
        redirect_to admin_space_availability_blocks_path(@space), notice: 'Bloqueo eliminado'
      end

      private

      def set_space
        @space = Space.find(params.expect(:space_id))
      end

      def block_full_day?
        params[:block_full_day] == '1' && params[:blocked_date].present?
      end

      def build_full_day_block
        date = Date.parse(params[:blocked_date])
        @space.availability_blocks.build(
          start_at: date.beginning_of_day,
          end_at: date.end_of_day,
          reason: params.dig(:availability_block, :reason)
        )
      end

      def block_params
        params.expect(availability_block: %i[start_at end_at reason])
      end
    end
  end
end
