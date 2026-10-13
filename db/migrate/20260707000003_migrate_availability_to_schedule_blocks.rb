# frozen_string_literal: true

class MigrateAvailabilityToScheduleBlocks < ActiveRecord::Migration[8.0]
  class MigrationSpace < ApplicationRecord
    self.table_name = 'boxes'
    has_many :availability_rules, foreign_key: :box_id
    has_many :slot_rates, foreign_key: :space_id
    has_many :schedule_blocks, foreign_key: :space_id
  end

  class MigrationAvailabilityRule < ApplicationRecord
    self.table_name = 'availability_rules'
    belongs_to :space, class_name: 'MigrateAvailabilityToScheduleBlocks::MigrationSpace', foreign_key: :box_id
  end

  class MigrationSlotRate < ApplicationRecord
    self.table_name = 'slot_rates'
    belongs_to :space, class_name: 'MigrateAvailabilityToScheduleBlocks::MigrationSpace', foreign_key: :space_id
  end

  class MigrationScheduleBlock < ApplicationRecord
    self.table_name = 'schedule_blocks'
  end

  class MigrationPricingRule < ApplicationRecord
    self.table_name = 'pricing_rules'
  end

  def up
    MigrationSpace.find_each do |space|
      next if space.schedule_blocks.exists?

      slot_duration = space.slot_duration_minutes.presence || 60
      rules = MigrationAvailabilityRule.where(box_id: space.id)

      rules.find_each do |rule|
        next unless rule.start_time && rule.end_time

        current = combine_time(rule.start_time)
        rule_end = combine_time(rule.end_time)
        position = 0

        while current + slot_duration.minutes <= rule_end
          block_start = current
          block_end = current + slot_duration.minutes
          price = price_for_block(space, block_start)

          MigrationScheduleBlock.create!(
            space_id: space.id,
            day_of_week: rule.day_of_week,
            start_time: block_start,
            end_time: block_end,
            price_cents: price,
            position: position
          )

          position += 1
          current = block_end
        end
      end
    end

    volume_rule = MigrationPricingRule.find_by(name: 'Descuento por volumen', rule_type: 0)
    if volume_rule && volume_rule.space_id.nil?
      MigrationSpace.find_each do |space|
        MigrationPricingRule.create!(
          name: volume_rule.name,
          rule_type: volume_rule.rule_type,
          config: volume_rule.config,
          active: volume_rule.active,
          stackable: volume_rule.stackable,
          priority: volume_rule.priority,
          space_id: space.id
        )
      end
      volume_rule.delete
    end
  end

  def down
    MigrationScheduleBlock.delete_all
  end

  private

  def combine_time(time)
    Time.zone.parse("2000-01-01 #{time.strftime('%H:%M:%S')}")
  end

  def price_for_block(space, block_start)
    rates = MigrationSlotRate.where(space_id: space.id).order(:position)
    rate = rates.find do |r|
      seconds = block_start.seconds_since_midnight
      start_s = combine_time(r.start_time).seconds_since_midnight
      end_s = combine_time(r.end_time).seconds_since_midnight
      seconds >= start_s && seconds < end_s
    end

    return rate.price_per_slot_cents if rate

    hourly = space.price_per_hour_cents.to_i
    duration = space.slot_duration_minutes.presence || 60
    (hourly * (duration / 60.0)).round
  end
end
