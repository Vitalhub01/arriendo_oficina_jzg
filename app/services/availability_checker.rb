# frozen_string_literal: true

class AvailabilityChecker
  PERIOD_BOOKING_BLOCKED_MESSAGE =
    'Hay al menos una hora reservada o bloqueada en esa fecha; no se puede reservar el bloque o la jornada completa.'.freeze

  attr_reader :error_message

  def initialize(box)
    @box = box
  end

  def slot_rate_window_available?(date, slot_rate)
    @error_message = nil
    blocks = box.schedule_blocks_within_time_range(date, slot_rate.start_time, slot_rate.end_time)
    window_available?(date, blocks, fallback: 'No hay horario disponible para ese bloque en la fecha elegida')
  end

  def jornada_window_available?(date, jornada_definition)
    @error_message = nil
    blocks = box.schedule_blocks_within_time_range(date, jornada_definition.start_time, jornada_definition.end_time)
    window_available?(date, blocks, fallback: 'No hay horario disponible para jornada completa en la fecha elegida')
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

    ScheduleBlockResolver.new(box).interval_covers_schedule?(start_at, end_at)
  end

  def blocked?(start_at, end_at)
    box.availability_blocks.exists?(['start_at < ? AND end_at > ?', end_at, start_at])
  end

  def booked?(start_at, end_at)
    box.bookings.blocking_availability.exists?(['start_at < ? AND end_at > ?', end_at, start_at])
  end

  def window_available?(date, blocks, fallback:)
    if blocks.empty?
      mark_unavailable(fallback)
      return false
    end
    unless box.interval_from_contiguous_blocks(date, blocks)
      mark_unavailable(fallback)
      return false
    end

    blocks.each do |block|
      start_at = block.starts_at_on(date)
      end_at = block.ends_at_on(date)
      next if available?(start_at, end_at)

      @error_message = period_conflict_message
      return false
    end

    true
  end

  def period_conflict_message
    case @error_message
    when 'Ya reservado', 'Horario bloqueado'
      PERIOD_BOOKING_BLOCKED_MESSAGE
    else
      @error_message || PERIOD_BOOKING_BLOCKED_MESSAGE
    end
  end
end
