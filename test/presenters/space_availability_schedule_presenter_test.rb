# frozen_string_literal: true

require 'test_helper'

class SpaceAvailabilitySchedulePresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @space = boxes(:published_box)
    @week_start = 1.week.from_now.to_date.beginning_of_week(:monday)
    @entries = AvailabilityScheduleBuilder.new(@space, week_start: @week_start, week_count: 2).build_weeks
  end

  test 'serializes weeks with hora bloque and jornada shapes' do
    payload = SpaceAvailabilitySchedulePresenter.new(
      space: @space,
      schedule_week_entries: @entries,
      week_start: @week_start,
      interactive: false,
      login_prompt_on_slots: true
    ).as_json

    assert_equal @week_start.iso8601, payload[:initialWeekStart]
    assert_equal 2, payload[:weeks].size

    day = payload[:weeks].first[:days].find { |d| d[:hora].any? }
    assert day[:hora].first.key?(:start)
    assert day[:hora].first.key?(:checkoutUrl)

    bloque_day = payload[:weeks].first[:days].find { |d| d[:bloque].any? }
    assert bloque_day[:bloque].first.key?(:rateId)

    jornada_day = payload[:weeks].first[:days].find { |d| d[:jornada].present? }
    assert jornada_day[:jornada].key?(:checkoutUrl)
  end
end
