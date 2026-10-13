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
    unless schedule_interval_valid?(start_at, end_at)
      mark_unavailable('Horario no disponible en la agenda')
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

  def consecutive_slots_available?(start_at, block_count)
    blocks = ScheduleBlockResolver.consecutive_blocks_from(box, start_at, block_count)
    return false if blocks.size != block_count

    date = start_at.to_date
    end_at = blocks.last.ends_at_on(date)
    available?(start_at, end_at)
  end

  private

  attr_reader :box

  def mark_unavailable(message)
    @error_message = message
  end

  def schedule_interval_valid?(start_at, end_at)
    return false if box.schedule_blocks.none?

    ScheduleBlockResolver.new(box).interval_matches_schedule?(start_at, end_at)
  end

  def blocked?(start_at, end_at)
    box.availability_blocks.exists?(['start_at < ? AND end_at > ?', end_at, start_at])
  end

  def booked?(start_at, end_at)
    box.bookings.blocking_availability.exists?(['start_at < ? AND end_at > ?', end_at, start_at])
  end
end
