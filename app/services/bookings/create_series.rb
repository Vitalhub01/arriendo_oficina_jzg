# frozen_string_literal: true

module Bookings
  class CreateSeries
    def initialize(box:, renter:, params:)
      @box = box
      @renter = renter
      @params = params
    end

    def call
      series = BookingSeries.new(
        box: @box,
        renter: @renter,
        day_of_week: @params[:day_of_week].to_i,
        start_time: parse_time(@params[:start_time]),
        end_time: parse_end_time,
        starts_on: Date.parse(@params[:starts_on]),
        ends_on: Date.parse(@params[:ends_on])
      )

      conflicts = validate_occurrences(series)
      return failure(series, conflicts) if conflicts.any?

      ActiveRecord::Base.transaction do
        series.save!
        create_initial_bookings(series)
      end

      GenerateSeriesBookingsJob.perform_later(series.id)
      Result.new(success: true, series: series)
    rescue ActiveRecord::RecordInvalid
      Result.new(success: false, series: series, errors: series.errors.full_messages)
    end

    private

    def parse_time(time_str)
      Time.zone.parse("2000-01-01 #{time_str}")
    end

    def parse_end_time
      start = parse_time(@params[:start_time])
      start + @params[:hours].to_i.hours
    end

    def validate_occurrences(series)
      checker = AvailabilityChecker.new(@box)
      series.occurrences(limit: 26).filter_map do |date|
        start_at = combine(date, series.start_time)
        end_at = combine(date, series.end_time)
        next if checker.available?(start_at, end_at)

        { date: date, message: checker.error_message }
      end
    end

    def combine(date, time)
      Time.zone.local(date.year, date.month, date.day, time.hour, time.min)
    end

    def create_initial_bookings(series)
      series.occurrences(limit: 4).each do |date|
        start_at = combine(date, series.start_time)
        end_at = combine(date, series.end_time)
        @box.bookings.create!(
          renter: @renter,
          booking_series: series,
          start_at: start_at,
          end_at: end_at,
          hours: series.hours,
          total_amount_cents: @box.price_for_duration(series.hours),
          status: :pending_payment
        )
      end
    end

    def failure(series, conflicts)
      Result.new(
        success: false,
        series: series,
        errors: ['Hay fechas con conflictos de disponibilidad'],
        conflicts: conflicts
      )
    end

    class Result
      attr_reader :series, :errors, :conflicts

      def initialize(success:, series: nil, errors: [], conflicts: [])
        @success = success
        @series = series
        @errors = errors
        @conflicts = conflicts
      end

      def success?
        @success
      end
    end
  end
end
