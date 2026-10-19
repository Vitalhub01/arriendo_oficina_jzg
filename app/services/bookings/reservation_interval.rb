# frozen_string_literal: true

module Bookings
  class ReservationInterval
    MODES = %w[hora bloque jornada].freeze

    def initialize(space:, params:)
      @space = space
      @params = params
      @mode = normalize_mode(params[:reservation_mode])
    end

    attr_reader :mode, :booking_type, :jornada_definition, :slot_rate

    def resolve
      date = parse_date
      return failure('Indica una fecha válida') unless date

      case mode
      when 'hora'
        resolve_hora(date)
      when 'bloque'
        resolve_bloque(date)
      when 'jornada'
        resolve_jornada(date)
      else
        failure('Tipo de reserva no válido')
      end
    end

    private

    attr_reader :space, :params

    def normalize_mode(value)
      mode = value.to_s.presence || 'hora'
      MODES.include?(mode) ? mode : 'hora'
    end

    def parse_date
      Date.parse(params[:date].to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def resolve_hora(date)
      slot_count = resolve_hourly_slot_count
      hour, min = params[:start_time].to_s.split(':').map(&:to_i)
      start_at = Time.zone.local(date.year, date.month, date.day, hour, min)

      blocks = ScheduleBlockResolver.consecutive_blocks_from(space, start_at, slot_count)
      if blocks.any?
        end_at = blocks.last.ends_at_on(date)
      else
        end_at = start_at + (slot_count * space.slot_duration_minutes).minutes
      end

      @booking_type = :slot_based
      success(start_at, end_at)
    end

    def resolve_bloque(date)
      @slot_rate = space.slot_rates.find_by(id: params[:slot_rate_id])
      return failure('Elige mañana o tarde') unless slot_rate

      interval = space.schedule_interval_for_slot_rate(date, slot_rate)
      return failure('No hay horario disponible para ese bloque en la fecha elegida') unless interval

      @booking_type = :hourly
      success(interval[:start_at], interval[:end_at])
    end

    def resolve_jornada(date)
      @jornada_definition = space.jornada_definitions.active.order(:position, :id).first
      return failure('Este espacio no tiene jornada completa configurada') unless jornada_definition

      interval = space.schedule_interval_for_jornada(date, jornada_definition)
      return failure('No hay horario disponible para jornada completa en la fecha elegida') unless interval

      @booking_type = :jornada
      success(interval[:start_at], interval[:end_at])
    end

    def resolve_hourly_slot_count
      if params[:slot_count].present?
        params[:slot_count].to_i
      elsif params[:hours].present?
        hours = params[:hours].to_i
        slots = (hours * 60.0 / space.slot_duration_minutes).ceil
        [slots, space.minimum_slots].max
      else
        space.minimum_slots
      end
    end

    def success(start_at, end_at)
      Result.new(
        success: true,
        start_at: start_at,
        end_at: end_at,
        mode: mode,
        booking_type: booking_type,
        jornada_definition: jornada_definition,
        slot_rate: slot_rate
      )
    end

    def failure(message)
      Result.new(success: false, errors: [message])
    end

    class Result
      attr_reader :start_at, :end_at, :errors, :mode, :booking_type, :jornada_definition, :slot_rate

      def initialize(success:, start_at: nil, end_at: nil, errors: [], mode: nil, booking_type: nil,
                     jornada_definition: nil, slot_rate: nil)
        @success = success
        @start_at = start_at
        @end_at = end_at
        @errors = errors
        @mode = mode
        @booking_type = booking_type
        @jornada_definition = jornada_definition
        @slot_rate = slot_rate
      end

      def success?
        @success
      end
    end
  end
end
