# frozen_string_literal: true

module ScheduleBlocks
  # Crea bloques de agenda a partir de availability_rules cuando un espacio publicado
  # aún no tiene plantilla (p. ej. migración incompleta o espacio nuevo vía flujo legacy).
  class GenerateFromRules
    def self.call(space)
      new(space).call
    end

    def initialize(space)
      @space = space
    end

    def call
      return false if @space.schedule_blocks.exists?

      rules = @space.availability_rules
      return false if rules.none?

      slot_duration = @space.slot_duration_minutes
      created = false

      rules.find_each do |rule|
        next unless rule.start_time && rule.end_time

        current = rule.start_time
        rule_end = rule.end_time
        position = 0

        while current + slot_duration.minutes <= rule_end
          block_end = current + slot_duration.minutes
          price = @space.price_per_slot_at(
            Time.zone.local(2000, 1, 1, current.hour, current.min)
          )

          block = ScheduleBlock.find_or_create_by!(
            space: @space,
            day_of_week: rule.day_of_week,
            start_time: current
          ) do |b|
            b.end_time = block_end
            b.price_cents = price
            b.position = position
          end
          created = true if block.previously_new_record?

          position += 1
          current = block_end
        end
      end

      created
    end
  end
end
