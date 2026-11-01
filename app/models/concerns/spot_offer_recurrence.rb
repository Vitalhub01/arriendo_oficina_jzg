# frozen_string_literal: true

module SpotOfferRecurrence
  extend ActiveSupport::Concern

  ALL_WEEKDAYS = (0..6).to_a.freeze
  WEEKDAY_WORKDAYS = [0, 1, 2, 3, 4].freeze

  class_methods do
    def app_wday_from_date(date)
      (date.wday + 6) % 7
    end
  end

  def normalized_weekdays
    Array(weekdays).map(&:to_i).uniq.sort.intersection(ALL_WEEKDAYS)
  end

  def weekday_names
    normalized_weekdays.map { |d| AvailabilityRule::DAY_NAMES[d] }
  end

  def weekdays_summary
    days = normalized_weekdays
    return 'Sin días seleccionados' if days.empty?
    return 'Todos los días' if days.size == ALL_WEEKDAYS.size
    return 'Lunes a viernes' if days == WEEKDAY_WORKDAYS

    weekday_names.to_sentence(two_words_connector: ' y ', last_word_connector: ' y ')
  end

  def recurrence_description
    return weekdays_summary if starts_on.blank? || ends_on.blank?

    time_range = "#{daily_start_time.strftime('%H:%M')}–#{daily_end_time.strftime('%H:%M')}"
    "Cada #{weekdays_summary.downcase}, #{time_range}, del #{I18n.l(starts_on)} al #{I18n.l(ends_on)}"
  end

  def build_occurrences
    return [] if normalized_weekdays.empty?
    return [] unless space && starts_on && ends_on && daily_start_time && daily_end_time
    SpotOffers::BuildOccurrences.new(
      space: space,
      starts_on: starts_on,
      ends_on: ends_on,
      daily_start_time: daily_start_time,
      daily_end_time: daily_end_time,
      weekdays: normalized_weekdays
    ).call
  end
end
