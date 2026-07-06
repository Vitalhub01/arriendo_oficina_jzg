# frozen_string_literal: true

class AvailabilityScheduleBuilder
  Slot = Struct.new(:starts_at, :available, keyword_init: true)

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
    rules = box.availability_rules.active_on(date).for_day(day_of_week)
    return [] if rules.empty?

    slot_starts = Set.new
    rules.each do |rule|
      slot_starts.merge(slot_start_times_for_rule(date, rule))
    end

    slot_starts.sort.map do |slot_start|
      slot_end = slot_start + box.slot_duration
      Slot.new(starts_at: slot_start, available: slot_available?(slot_start, slot_end))
    end
  end

  def slot_start_times_for_rule(date, rule)
    starts = []
    slot_duration = box.slot_duration_minutes.minutes
    current = combine_date_time(date, rule.start_time)
    rule_end = combine_date_time(date, rule.end_time)

    while current + slot_duration <= rule_end
      starts << current
      current += slot_duration
    end

    starts
  end

  def slot_available?(start_at, end_at)
    AvailabilityChecker.new(box).available?(start_at, end_at)
  end

  def combine_date_time(date, time)
    Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
  end
end
