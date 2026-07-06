# frozen_string_literal: true

class MigrateJornadaDefinitionsToSlotRates < ActiveRecord::Migration[8.0]
  class MigrationJornadaDefinition < ApplicationRecord
    self.table_name = 'jornada_definitions'
  end

  class MigrationSlotRate < ApplicationRecord
    self.table_name = 'slot_rates'
  end

  class MigrationSpace < ApplicationRecord
    self.table_name = 'boxes'
  end

  def up
    return unless table_exists?(:jornada_definitions)

    office_jornadas = MigrationJornadaDefinition.where.not(office_id: nil).where(space_id: nil).order(:position, :name)
    return if office_jornadas.empty?

    MigrationSpace.find_each do |space|
      office_jornadas.each_with_index do |jornada, index|
        slot_count = slot_count_for(jornada, space)
        next if slot_count <= 0

        price_per_slot = (jornada.price_cents.to_f / slot_count).round

        MigrationSlotRate.find_or_create_by!(
          space_id: space.id,
          name: jornada.name,
          start_time: jornada.start_time,
          end_time: jornada.end_time
        ) do |rate|
          rate.price_per_slot_cents = price_per_slot
          rate.position = index
        end
      end
    end

    MigrationJornadaDefinition.where.not(space_id: nil).find_each do |jornada|
      space = MigrationSpace.find_by(id: jornada.space_id)
      next unless space

      slot_count = slot_count_for(jornada, space)
      next if slot_count <= 0

      price_per_slot = (jornada.price_cents.to_f / slot_count).round

      MigrationSlotRate.find_or_create_by!(
        space_id: space.id,
        name: jornada.name,
        start_time: jornada.start_time,
        end_time: jornada.end_time
      ) do |rate|
        rate.price_per_slot_cents = price_per_slot
        rate.position = jornada.position
      end
    end
  end

  def down
    MigrationSlotRate.delete_all
  end

  private

  def slot_count_for(jornada, space)
    duration_minutes = space.slot_duration_minutes.presence || 60
    window_minutes = ((jornada.end_time - jornada.start_time) / 60).to_i
    return 0 if window_minutes <= 0

    (window_minutes.to_f / duration_minutes).floor
  end
end
