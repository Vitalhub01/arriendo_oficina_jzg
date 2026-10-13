# frozen_string_literal: true

module Admin
  module Spaces
    class ScheduleBlocksController < Admin::BaseController
      before_action :set_space
      before_action :set_schedule_block, only: %i[update destroy]

      def index
        @schedule_blocks = @space.schedule_blocks.order(:day_of_week, :position, :start_time)
        @volume_rules = @space.pricing_rules.volume_discount.order(priority: :desc)
        @volume_rule = @space.pricing_rules.volume_discount.new(active: true, priority: 10)
      end

      def create
        @schedule_block = @space.schedule_blocks.build(schedule_block_params)

        if @schedule_block.save
          respond_to do |format|
            format.html { redirect_to admin_space_schedule_blocks_path(@space), notice: 'Bloque creado' }
            format.json { render json: serialize_block(@schedule_block), status: :created }
          end
        else
          respond_to do |format|
            format.html { redirect_to admin_space_schedule_blocks_path(@space), alert: @schedule_block.errors.full_messages.to_sentence }
            format.json { render json: { errors: @schedule_block.errors.full_messages }, status: :unprocessable_content }
          end
        end
      end

      def update
        if @schedule_block.update(schedule_block_params)
          respond_to do |format|
            format.html { redirect_to admin_space_schedule_blocks_path(@space), notice: 'Bloque actualizado' }
            format.json { render json: serialize_block(@schedule_block) }
          end
        else
          respond_to do |format|
            format.html { redirect_to admin_space_schedule_blocks_path(@space), alert: @schedule_block.errors.full_messages.to_sentence }
            format.json { render json: { errors: @schedule_block.errors.full_messages }, status: :unprocessable_content }
          end
        end
      end

      def destroy
        @schedule_block.destroy
        respond_to do |format|
          format.html { redirect_to admin_space_schedule_blocks_path(@space), notice: 'Bloque eliminado' }
          format.json { head :no_content }
        end
      end

      private

      def set_space
        @space = Space.find(params.expect(:space_id))
      end

      def set_schedule_block
        @schedule_block = @space.schedule_blocks.find(params.expect(:id))
      end

      def schedule_block_params
        raw = params.require(:schedule_block).permit(
          :day_of_week, :start_time, :end_time, :name, :position, :price_clp, :price_cents
        )
        if raw[:price_clp].present?
          raw[:price_cents] = (raw.delete(:price_clp).to_f * 100).round
        end
        raw
      end

      def serialize_block(block)
        {
          id: block.id,
          day_of_week: block.day_of_week,
          start_time: block.start_time.strftime('%H:%M'),
          end_time: block.end_time.strftime('%H:%M'),
          price_cents: block.price_cents,
          price_clp: block.price_cents / 100.0,
          name: block.name,
          position: block.position,
          duration_minutes: block.duration_minutes
        }
      end
    end
  end
end
