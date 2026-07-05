# frozen_string_literal: true

class AvailabilityScheduleBuilder
  Slot = Struct.new(:hour, :available, keyword_init: true)

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
        slots: hourly_slots_for(date, day_of_week)
      }
    end
  end

  private

  attr_reader :box

  def hourly_slots_for(date, day_of_week)
    rules = box.availability_rules.active_on(date).for_day(day_of_week)
    return [] if rules.empty?

    hours = Set.new
    rules.each do |rule|
      start_hour = rule.start_time.hour
      end_hour = rule.end_time.hour
      (start_hour...end_hour).each { |h| hours << h }
    end

    hours.sort.map do |hour|
      slot_start = Time.zone.local(date.year, date.month, date.day, hour)
      slot_end = slot_start + 1.hour
      Slot.new(hour: hour, available: slot_available?(slot_start, slot_end))
    end
  end

  def slot_available?(start_at, end_at)
    AvailabilityChecker.new(box).available?(start_at, end_at)
  end
end
