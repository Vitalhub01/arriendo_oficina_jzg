# frozen_string_literal: true

module ScheduleBlocks
  # Evita borrar o mover plantillas semanales que cubren reservas confirmadas o pendientes de pago.
  class BookingGuard
    class << self
      def protected?(space, block)
        upcoming_overlapping(space, block).any?
      end

      def upcoming_overlapping(space, block)
        candidates = space.bookings.blocking_availability.where('start_at >= ?', Time.current)
        candidates.find_all { |booking| overlaps?(booking, block) }
      end

      def overlaps?(booking, block)
        day = schedule_day_index(booking.start_at)
        return false unless day == block.day_of_week

        date = booking.start_at.to_date
        zone_start = block.starts_at_on(date)
        zone_end = block.ends_at_on(date)
        booking.start_at < zone_end && booking.end_at > zone_start
      end

      def destruction_blocked_message(blocks)
        count = Array(blocks).size
        if count == 1
          'Hay reservas activas en este horario; no se puede quitar ni reemplazar la plantilla.'
        else
          "Hay reservas activas en #{count} franjas; no se pueden quitar ni reemplazar."
        end
      end

      def template_time_change_blocked_message
        'Hay reservas activas en este horario; no se puede cambiar el día ni la ventana horaria de la plantilla.'
      end

      def end_series_blocked_message
        'Hay reservas activas desde esa fecha en adelante; no se puede finalizar la serie aquí.'
      end

      private

      def schedule_day_index(time)
        (time.wday + 6) % 7
      end
    end
  end
end
