# frozen_string_literal: true

class AvailabilityChecker
  attr_reader :error_message

  def initialize(box)
    @box = box
  end

  def available?(start_at, end_at)
    @error_message = nil
    if end_at <= start_at
      mark_unavailable('Horario inválido')
      return false
    end
    unless within_rules?(start_at, end_at)
      mark_unavailable('Fuera del horario ofrecido')
      return false
    end
    if blocked?(start_at, end_at)
      mark_unavailable('Horario bloqueado')
      return false
    end
    if booked?(start_at, end_at)
      mark_unavailable('Ya reservado')
      return false
    end

    true
  end

  private

  attr_reader :box

  def mark_unavailable(message)
    @error_message = message
  end

  def within_rules?(start_at, end_at)
    day = iso_day_of_week(start_at)
    rules = box.availability_rules.active_on(start_at.to_date).for_day(day)
    return false if rules.empty?

    rules.any? do |rule|
      rule_start = combine_date_time(start_at.to_date, rule.start_time)
      rule_end = combine_date_time(start_at.to_date, rule.end_time)
      start_at >= rule_start && end_at <= rule_end
    end
  end

  def blocked?(start_at, end_at)
    box.availability_blocks.exists?(['start_at < ? AND end_at > ?', end_at, start_at])
  end

  def booked?(start_at, end_at)
    box.bookings.blocking_availability.exists?(['start_at < ? AND end_at > ?', end_at, start_at])
  end

  def iso_day_of_week(time)
    # 0=Monday .. 6=Sunday
    (time.wday + 6) % 7
  end

  def combine_date_time(date, time)
    Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
  end
end
