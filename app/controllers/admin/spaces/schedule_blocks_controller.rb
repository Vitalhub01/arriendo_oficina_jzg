# frozen_string_literal: true

module Admin
  module Spaces
    class ScheduleBlocksController < Admin::BaseController
      before_action :set_space
      before_action :set_schedule_block, only: %i[update destroy upsert_override destroy_override]
      before_action :set_week_start

      def index
        @schedule_blocks = @space.schedule_blocks.order(:day_of_week, :position, :start_time)
        @overrides = @space.schedule_block_overrides.for_week(@week_start).index_by do |o|
          [o.schedule_block_id, o.date]
        end
        @volume_rules = @space.pricing_rules.volume_discount.order(priority: :desc)
        @volume_rule = @space.pricing_rules.volume_discount.new(active: true, priority: 10)
      end

      def create
        remove_overlapping_blocks!
        @schedule_block = @space.schedule_blocks.build(schedule_block_params)

        if @schedule_block.save
          respond_with_block('Bloque creado', :created)
        else
          respond_with_errors(@schedule_block.errors.full_messages)
        end
      end

      def update
        remove_overlapping_blocks!
        if @schedule_block.update(schedule_block_params)
          respond_with_block('Bloque actualizado')
        else
          respond_with_errors(@schedule_block.errors.full_messages)
        end
      end

      def destroy
        @schedule_block.destroy
        respond_to do |format|
          format.html { redirect_to schedule_index_path, notice: 'Bloque eliminado de la plantilla semanal' }
          format.json { head :no_content }
        end
      end

      def upsert_override
        date = Date.parse(params.require(:date))
        override = @schedule_block.overrides.find_or_initialize_by(date: date, space: @space)

        if params[:blocked] == '1' || params[:blocked] == true
          override.blocked = true
          override.price_cents = nil
          override.reason = params[:reason]
        elsif params[:price_clp].present?
          override.blocked = false
          override.price_cents = (params[:price_clp].to_f * 100).round
          override.reason = nil
        else
          return respond_with_errors(['Indica precio o bloqueo'])
        end

        if override.save
          respond_to do |format|
            format.html { redirect_to schedule_index_path(week_start: @week_start), notice: 'Cambio guardado para esta fecha' }
            format.json { render json: serialize_override(override) }
          end
        else
          respond_with_errors(override.errors.full_messages)
        end
      end

      def destroy_override
        date = Date.parse(params.require(:date))
        override = @schedule_block.overrides.find_by(date: date)
        override&.destroy

        respond_to do |format|
          format.html { redirect_to schedule_index_path, notice: 'Se restauró la plantilla semanal para esta fecha' }
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

      def set_week_start
        @week_start = parse_week_start
      end

      def parse_week_start
        if params[:week_start].present?
          Date.parse(params[:week_start]).beginning_of_week(:monday)
        else
          Date.current.beginning_of_week(:monday)
        end
      rescue ArgumentError
        Date.current.beginning_of_week(:monday)
      end

      def schedule_index_path(extra = {})
        admin_space_schedule_blocks_path(@space, extra)
      end

      def remove_overlapping_blocks!
        ids = Array(params[:remove_overlapping_ids]).map(&:to_i).reject(&:zero?)
        return if ids.empty?

        @space.schedule_blocks.where(id: ids).destroy_all
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

      def respond_with_block(notice, json_status = :ok)
        respond_to do |format|
          format.html { redirect_to schedule_index_path(week_start: params[:week_start]), notice: notice }
          format.json { render json: serialize_block(@schedule_block), status: json_status }
        end
      end

      def respond_with_errors(errors)
        respond_to do |format|
          format.html { redirect_to schedule_index_path, alert: errors.to_sentence }
          format.json { render json: { errors: errors }, status: :unprocessable_content }
        end
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

      def serialize_override(override)
        {
          schedule_block_id: override.schedule_block_id,
          date: override.date.iso8601,
          blocked: override.blocked,
          price_cents: override.price_cents,
          price_clp: override.price_cents ? override.price_cents / 100.0 : nil
        }
      end
    end
  end
end
