# frozen_string_literal: true

class GenerateSeriesBookingsJob < ApplicationJob
  queue_as :default

  def perform(series_id)
    series = BookingSeries.find_by(id: series_id)
    return unless series&.active?

    horizon = 8.weeks.from_now.to_date
    end_date = [series.ends_on, horizon].min

    date = Date.current
    while date <= end_date
      create_booking_if_needed(series, date) if date.wday == ruby_wday(series.day_of_week) && date >= series.starts_on
      date += 1.day
    end
  end

  private

  def ruby_wday(day_of_week)
    day_of_week == 6 ? 0 : day_of_week + 1
  end

  def create_booking_if_needed(series, date)
    start_at = Time.zone.local(date.year, date.month, date.day, series.start_time.hour, series.start_time.min)
    end_at = Time.zone.local(date.year, date.month, date.day, series.end_time.hour, series.end_time.min)

    return if series.bookings.exists?(start_at: start_at)
    return unless AvailabilityChecker.new(series.box).available?(start_at, end_at)

    series.box.bookings.create!(
      renter: series.renter,
      booking_series: series,
      start_at: start_at,
      end_at: end_at,
      hours: series.hours,
      total_amount_cents: series.box.price_for_duration(series.hours),
      status: :pending_payment
    )
  end
end
