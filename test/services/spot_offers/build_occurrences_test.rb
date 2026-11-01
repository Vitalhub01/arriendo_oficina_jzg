# frozen_string_literal: true

require 'test_helper'

module SpotOffers
  class BuildOccurrencesTest < ActiveSupport::TestCase
    test 'finds daily window on future weekdays' do
      space = boxes(:published_box)
      starts_on = 1.week.from_now.to_date.beginning_of_week(:monday)
      ends_on = starts_on + 2.days

      occurrences = BuildOccurrences.new(
        space: space,
        starts_on: starts_on,
        ends_on: ends_on,
        daily_start_time: Time.zone.parse('2000-01-01 08:00'),
        daily_end_time: Time.zone.parse('2000-01-01 14:00')
      ).call

      assert occurrences.any?
      assert occurrences.all? { |o| o[:start_at] < o[:end_at] }
    end

    test 'filters by selected weekdays only' do
      space = boxes(:published_box)
      starts_on = 1.week.from_now.to_date.beginning_of_week(:monday)
      ends_on = starts_on + 6.days

      all_days = BuildOccurrences.new(
        space: space,
        starts_on: starts_on,
        ends_on: ends_on,
        daily_start_time: Time.zone.parse('2000-01-01 08:00'),
        daily_end_time: Time.zone.parse('2000-01-01 14:00'),
        weekdays: SpotOfferRecurrence::ALL_WEEKDAYS
      ).call

      tuesday_only = BuildOccurrences.new(
        space: space,
        starts_on: starts_on,
        ends_on: ends_on,
        daily_start_time: Time.zone.parse('2000-01-01 08:00'),
        daily_end_time: Time.zone.parse('2000-01-01 14:00'),
        weekdays: [1]
      ).call

      assert tuesday_only.size < all_days.size
      assert tuesday_only.all? { |o| SpotOffer.app_wday_from_date(o[:date]) == 1 }
    end
  end
end
