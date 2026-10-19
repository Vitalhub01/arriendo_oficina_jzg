# frozen_string_literal: true

module Admin
  module Spaces
    class ScheduleBlocksController < Admin::BaseController
      before_action :set_space
      before_action :set_schedule_block, only: %i[update destroy upsert_override destroy_override end_series_from_date]
      before_action :set_week_start

      def index
        @schedule_blocks = @space.schedule_blocks.order(:day_of_week, :position, :start_time)
        @overrides = @space.schedule_block_overrides.for_week(@week_start).index_by do |o|
          [o.schedule_block_id, o.date]
        end
        @volume_rules = @space.pricing_rules.volume_discount.order(priority: :desc)
        @volume_rule = @space.pricing_rules.volume_discount.new(active: true, priority: 10)
      end

      def bulk_fill
        result = ScheduleBlocks::BulkFill.call(
          space: @space,
          days: bulk_fill_days,
          start_time: params.require(:start_time),
          end_time: params.require(:end_time),
          price_cents: bulk_fill_price_cents,
          replace_overlapping: params[:replace_overlapping] == '1' || params[:replace_overlapping] == true
        )

        if result.success?
          notice = "Se crearon #{result.created_count} bloques"
          notice += " (se quitaron #{result.removed_count} anteriores)" if result.removed_count.positive?
          respond_to do |format|
            format.html { redirect_to schedule_index_path(week_start: @week_start), notice: notice }
            format.json { render json: { created_count: result.created_count, removed_count: result.removed_count } }
          end
        else
          respond_with_errors(result.errors)
        end
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

      def end_series_from_date
        from_date = Date.parse(params.require(:from_date))
        new_until = from_date - 1.day
        current_until = @schedule_block.effective_until
        effective_until = if current_until.present?
                            [current_until, new_until].min
                          else
                            new_until
                          end

        if @schedule_block.update(effective_until: effective_until)
          respond_to do |format|
            format.html do
              redirect_to schedule_index_path(week_start: @week_start), notice: 'Horario finalizado desde la fecha indicada'
            end
            format.json { render json: serialize_block(@schedule_block) }
          end
        else
          respond_with_errors(@schedule_block.errors.full_messages)
        end
      end

      def upsert_override
        date = Date.parse(params.require(:date))
        override = @schedule_block.overrides.find_or_initialize_by(date: date, space: @space)

        if params[:blocked] == '1' || params[:blocked] == true
          override.blocked = true
          override.price_cents = nil
          override.start_time = nil
          override.end_time = nil
          override.reason = params[:reason]
        elsif date_override_payload?
          overlap_error = ensure_date_overlap_resolved!(date, override)
          return respond_with_errors([overlap_error]) if overlap_error

          block_overlapping_on_date!(date)
          override.blocked = false
          apply_date_override_fields!(override)
        else
          return respond_with_errors(['Indica precio, horario o bloqueo'])
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

      def bulk_fill_days
        Array(params[:days]).map(&:to_i).select { |d| d.in?(0..6) }
      end

      def bulk_fill_price_cents
        return nil if params[:price_clp].blank?

        params[:price_clp].to_f.round
      end

      def schedule_block_params
        raw = params.require(:schedule_block).permit(
          :day_of_week, :start_time, :end_time, :name, :position, :price_clp, :price_cents
        )
        if raw[:price_clp].present?
          raw[:price_cents] = raw.delete(:price_clp).to_f.round
        end
        raw
      end

      def date_override_payload?
        params[:price_clp].present? || params[:start_time].present? || params[:end_time].present?
      end

      def apply_date_override_fields!(override)
        if params[:price_clp].present?
          override.price_cents = params[:price_clp].to_f.round
        end
        if params[:start_time].present? && params[:end_time].present?
          override.start_time = params[:start_time]
          override.end_time = params[:end_time]
        end
        override.reason = nil
      end

      def ensure_date_overlap_resolved!(date, _override)
        return unless params[:start_time].present? && params[:end_time].present?

        overlapping = overlapping_blocks_on_date(
          date, @schedule_block, params[:start_time], params[:end_time]
        )
        return if overlapping.empty?

        ids = Array(params[:block_overlapping_ids]).map(&:to_i).reject(&:zero?)
        return if overlapping.all? { |block| ids.include?(block.id) }

        labels = overlapping.map { |b| format_interval_on_date(b, date) }.join(', ')
        "se solapa con otro horario este día (#{labels})"
      end

      def overlapping_blocks_on_date(date, block, start_time, end_time)
        day = (date.wday + 6) % 7
        range_start = time_on_date(date, start_time)
        range_end = time_on_date(date, end_time)
        return [] if range_end <= range_start

        @space.schedule_blocks.for_day(day).where.not(id: block.id).select do |other|
          next false if other.blocked_on?(date)

          other_start = other.starts_at_on(date)
          other_end = other.ends_at_on(date)
          range_start < other_end && range_end > other_start
        end
      end

      def block_overlapping_on_date!(date)
        ids = Array(params[:block_overlapping_ids]).map(&:to_i).reject(&:zero?)
        return if ids.empty?

        ids.each do |block_id|
          other = @space.schedule_blocks.find_by(id: block_id)
          next unless other

          other_override = other.overrides.find_or_initialize_by(date: date, space: @space)
          other_override.blocked = true
          other_override.price_cents = nil
          other_override.start_time = nil
          other_override.end_time = nil
          other_override.save!
        end
      end

      def time_on_date(date, time_value)
        time = time_value.is_a?(String) ? Time.zone.parse(time_value) : time_value
        Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
      end

      def format_interval_on_date(block, date)
        "#{block.start_time_on(date).strftime('%H:%M')}–#{block.end_time_on(date).strftime('%H:%M')}"
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
          price_clp: block.price_cents,
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
          price_clp: override.price_cents,
          start_time: override.start_time&.strftime('%H:%M'),
          end_time: override.end_time&.strftime('%H:%M')
        }
      end
    end
  end
end
