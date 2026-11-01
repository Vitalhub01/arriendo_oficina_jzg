# frozen_string_literal: true

require 'test_helper'

class SpotOfferRecurrenceTest < ActiveSupport::TestCase
  test 'weekdays summary for workdays and custom sets' do
    offer = SpotOffer.new(weekdays: SpotOfferRecurrence::WEEKDAY_WORKDAYS)
    assert_equal 'Lunes a viernes', offer.weekdays_summary

    offer.weekdays = [1, 3]
    assert_equal 'Martes y Jueves', offer.weekdays_summary
  end
end
