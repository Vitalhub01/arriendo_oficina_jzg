# frozen_string_literal: true

module Bookings
  class Quote
    def initialize(space:, params:, user: nil)
      @space = space
      @params = params.to_h.with_indifferent_access
      @user = user
    end

    def call
      interval = ReservationInterval.new(space: @space, params: @params).resolve
      return failure(interval.errors) unless interval.success?

      start_at = interval.start_at
      end_at = interval.end_at
      duration_minutes = ((end_at - start_at) / 60).to_i
      slot_count = slot_count_for(start_at, end_at, duration_minutes)

      equipment_usage = @space.equipment_usage_from_params(@params)

      pricing = PricingEngine.calculate(
        @space,
        @user,
        start_at,
        slot_count,
        end_at: end_at,
        booking_type: interval.booking_type,
        jornada_definition: interval.jornada_definition,
        slot_rate: interval.slot_rate,
        equipment_usage: equipment_usage
      )

      Result.new(
        success: true,
        interval: interval,
        start_at: start_at,
        end_at: end_at,
        duration_minutes: duration_minutes,
        slot_count: slot_count,
        pricing: pricing
      )
    end

    private

    def slot_count_for(start_at, end_at, duration_minutes)
      count = @space.schedule_block_count_for_interval(start_at, end_at)
      return count if count.positive?

      (duration_minutes.to_f / @space.slot_duration_minutes).ceil
    end

    def failure(errors)
      Result.new(success: false, errors: errors)
    end

    class Result
      attr_reader :interval, :start_at, :end_at, :duration_minutes, :slot_count, :pricing, :errors

      def initialize(success:, interval: nil, start_at: nil, end_at: nil, duration_minutes: nil,
                     slot_count: nil, pricing: nil, errors: [])
        @success = success
        @interval = interval
        @start_at = start_at
        @end_at = end_at
        @duration_minutes = duration_minutes
        @slot_count = slot_count
        @pricing = pricing
        @errors = errors
      end

      def success?
        @success
      end

      def total_cents
        pricing&.fetch(:total_cents, 0) || 0
      end

      def formatted_total
        Money.new(total_cents, 'CLP').format(no_cents_if_whole: true)
      end

      def reservation_mode
        interval&.mode || 'hora'
      end

      def mode_label
        case reservation_mode
        when 'bloque' then 'Bloque (mañana / tarde)'
        when 'jornada' then 'Jornada completa'
        else 'Por hora'
        end
      end
    end
  end
end
