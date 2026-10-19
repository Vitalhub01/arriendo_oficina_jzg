# frozen_string_literal: true

module ScheduleBlocks
  # Genera bloques de reserva en la plantilla semanal para varios días y un rango horario,
  # dividiendo el intervalo según slot_duration_minutes del espacio.
  class BulkFill
    Result = Struct.new(:created_count, :removed_count, :errors, keyword_init: true) do
      def success?
        errors.blank?
      end
    end

    def self.call(space:, days:, start_time:, end_time:, price_cents: nil, replace_overlapping: false)
      new(
        space: space,
        days: days,
        start_time: start_time,
        end_time: end_time,
        price_cents: price_cents,
        replace_overlapping: replace_overlapping
      ).call
    end

    def initialize(space:, days:, start_time:, end_time:, price_cents: nil, replace_overlapping: false)
      @space = space
      @days = Array(days).map(&:to_i).uniq.sort
      @start_time = start_time
      @end_time = end_time
      @price_cents = price_cents&.to_i
      @replace_overlapping = replace_overlapping
    end

    def call
      range_start = clock_time(@start_time)
      range_end = clock_time(@end_time)

      return failure(['Indica al menos un día de la semana']) if @days.empty?
      return failure(['La hora de fin debe ser posterior al inicio']) if range_end <= range_start
      return failure(['Día de la semana inválido']) if @days.any? { |d| d < 0 || d > 6 }

      created = 0
      removed = 0

      ApplicationRecord.transaction do
        @days.each do |day|
          if @replace_overlapping
            removed += remove_overlapping_on_day(day, range_start, range_end)
          end

          created += create_slots_for_day(day, range_start, range_end)
        end
      end

      Result.new(created_count: created, removed_count: removed, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      failure([e.record.errors.full_messages.to_sentence])
    end

    private

    def create_slots_for_day(day, range_start, range_end)
      slot_duration = @space.slot_duration_minutes.minutes
      current = range_start
      position = (@space.schedule_blocks.for_day(day).maximum(:position) || -1) + 1
      count = 0

      while current + slot_duration <= range_end
        block_end = current + slot_duration
        price = @price_cents || @space.price_per_slot_at(
          Time.zone.local(2000, 1, 1, current.hour, current.min)
        )

        block = @space.schedule_blocks.build(
          day_of_week: day,
          start_time: current,
          end_time: block_end,
          price_cents: price,
          position: position
        )

        if block.save
          count += 1
          position += 1
        elsif @replace_overlapping
          raise ActiveRecord::RecordInvalid, block
        end

        current = block_end
      end

      count
    end

    def remove_overlapping_on_day(day, range_start, range_end)
      scope = @space.schedule_blocks.for_day(day).where(
        'start_time < ? AND end_time > ?',
        range_end,
        range_start
      )
      count = scope.count
      scope.destroy_all
      count
    end

    def clock_time(value)
      if value.is_a?(String)
        hour, minute = value.split(':').map { |part| Integer(part, 10) }
        Time.zone.parse(format('2000-01-01 %02d:%02d:00', hour, minute))
      else
        Time.zone.parse("2000-01-01 #{value.strftime('%H:%M:%S')}")
      end
    end

    def failure(errors)
      Result.new(created_count: 0, removed_count: 0, errors: errors)
    end
  end
end
