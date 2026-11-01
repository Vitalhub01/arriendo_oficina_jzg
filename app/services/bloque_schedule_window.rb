# frozen_string_literal: true

# Horario mostrable de mañana/tarde según los schedule_blocks del día
# (p. ej. sábado tarde hasta 16:00 aunque el SlotRate template diga 20:00).
class BloqueScheduleWindow
  def self.labels_for(date, blocks, fallback_start:, fallback_end:)
    sorted = ScheduleBlock.sort_for_display_on(blocks, date)
    if sorted.empty?
      return {
        start: fallback_start.strftime('%H:%M'),
        end: fallback_end.strftime('%H:%M')
      }
    end

    {
      start: sorted.first.start_time_on(date).strftime('%H:%M'),
      end: sorted.last.end_time_on(date).strftime('%H:%M')
    }
  end
end
