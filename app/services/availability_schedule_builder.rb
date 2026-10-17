# frozen_string_literal: true

class AvailabilityScheduleBuilder
  Slot = Struct.new(:starts_at, :ends_at, :price_cents, :available, keyword_init: true)

  def initialize(box, week_start:)
    @box = box
    @week_start = week_start.to_date.beginning_of_week(:monday)
    @week_end = @week_start + 6.days
  end

  def build
    (0..6).map do |day_offset|
      date = @week_start + day_offset.days
      day_of_week = day_offset
      {
        date: date,
        day_name: AvailabilityRule::DAY_NAMES[day_of_week],
        slots: slots_for(date, day_of_week)
      }
    end
  end

  private

  attr_reader :box

  def slots_for(date, day_of_week)
    blocks = box.schedule_blocks.for_day(day_of_week).ordered
    return [] if blocks.empty?

    blocks.filter_map do |block|
      next if date < Date.current

      slot_start = block.starts_at_on(date)
      slot_end = block.ends_at_on(date)
      next if slot_start < Time.current

      Slot.new(
        starts_at: slot_start,
        ends_at: slot_end,
        price_cents: block.price_cents_on(date),
        available: slot_available?(slot_start, slot_end)
      )
    end
  end

  def slot_available?(start_at, end_at)
    AvailabilityChecker.new(box).available?(start_at, end_at)
  end
end
