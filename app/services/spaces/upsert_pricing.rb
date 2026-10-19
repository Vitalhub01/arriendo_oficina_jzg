# frozen_string_literal: true

module Spaces
  class UpsertPricing
    PERIODS = [
      { key: :morning, name: 'Mañana', start: '08:00', end: '13:00', position: 0 },
      { key: :afternoon, name: 'Tarde', start: '14:00', end: '19:00', position: 1 }
    ].freeze

    def initialize(space:, params:)
      @space = space
      @params = params.to_h.symbolize_keys
    end

    def call
      return Result.new(success: true) if @params.blank?

      ActiveRecord::Base.transaction do
        PERIODS.each { |period| upsert_slot_rate!(period) }
        upsert_jornada!
        ensure_jornada_pricing_rule!
        sync_space_hourly_fallback!
        sync_schedule_block_prices!
      end

      Result.new(success: true)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, errors: e.record.errors.full_messages)
    end

    private

    attr_reader :space, :params

    def upsert_slot_rate!(period)
      hourly_cents = params[:"#{period[:key]}_hourly_price_cents"]
      block_cents = params[:"#{period[:key]}_block_price_cents"]
      return if hourly_cents.blank? && block_cents.blank?

      rate = space.slot_rates.find_or_initialize_by(name: period[:name])
      rate.start_time ||= time_on(period[:start])
      rate.end_time ||= time_on(period[:end])
      rate.position = period[:position]
      rate.price_per_slot_cents = hourly_cents.to_i if hourly_cents.present?
      rate.block_price_cents = block_cents.to_i if block_cents.present?
      rate.save!
    end

    def upsert_jornada!
      jornada_cents = params[:jornada_price_cents]
      return if jornada_cents.blank?

      jornada = space.jornada_definitions.find_or_initialize_by(name: 'Jornada completa')
      jornada.office ||= space.office
      jornada.start_time ||= time_on('08:00')
      jornada.end_time ||= time_on('20:00')
      jornada.price_cents = jornada_cents.to_i
      jornada.active = true
      jornada.position = 0
      jornada.save!
    end

    def ensure_jornada_pricing_rule!
      return unless space.jornada_definitions.active.exists?

      PricingRule.find_or_create_by!(name: 'Tarifa jornada completa', space_id: space.id) do |rule|
        rule.rule_type = :jornada_rate
        rule.config = {}
        rule.active = true
        rule.priority = 5
      end
    end

    def sync_space_hourly_fallback!
      morning = space.slot_rates.find_by(name: 'Mañana')
      return unless morning&.price_per_slot_cents&.positive?

      space.update_column(:price_per_hour_cents, morning.price_per_slot_cents)
    end

    def sync_schedule_block_prices!
      space.slot_rates.ordered.each do |rate|
        space.schedule_blocks
             .where('start_time >= ? AND start_time < ?', rate.start_time, rate.end_time)
             .update_all(price_cents: rate.price_per_slot_cents)
      end
    end

    def time_on(hour_minute)
      Time.zone.parse("2000-01-01 #{hour_minute}")
    end

    class Result
      attr_reader :errors

      def initialize(success:, errors: [])
        @success = success
        @errors = errors
      end

      def success?
        @success
      end
    end
  end
end
