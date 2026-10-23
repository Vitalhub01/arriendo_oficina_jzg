# frozen_string_literal: true

module SpotOffers
  class BuildOccurrences
    def initialize(space:, starts_on:, ends_on:, daily_start_time:, daily_end_time:)
      @space = space
      @starts_on = starts_on.to_date
      @ends_on = ends_on.to_date
      @daily_start_time = daily_start_time
      @daily_end_time = daily_end_time
    end

    def call
      (@starts_on..@ends_on).filter_map do |date|
        next if date < Date.current

        interval = @space.schedule_interval_for_daily_window(date, @daily_start_time, @daily_end_time)
        next unless interval

        start_at = interval[:start_at]
        end_at = interval[:end_at]
        next unless AvailabilityChecker.new(@space).available?(start_at, end_at)

        { date: date, start_at: start_at, end_at: end_at }
      end
    end
  end
end
