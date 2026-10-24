# frozen_string_literal: true

require 'test_helper'

class AvailabilityScheduleBuilderTest < ActiveSupport::TestCase
  setup do
    @space = boxes(:published_box)
    @week_start = 1.week.from_now.to_date.beginning_of_week(:monday)
  end

  test 'builds slots from schedule blocks' do
    schedule = AvailabilityScheduleBuilder.new(@space, week_start: @week_start).build
    monday = schedule.find { |day| day[:day_name] == 'Lunes' }

    assert monday[:slots].any?
    first_slot = monday[:slots].first
    assert_equal 60, ((first_slot.ends_at - first_slot.starts_at) / 60).to_i
  end

  test 'reflects variable block durations' do
    @space.schedule_blocks.for_day(0).destroy_all
    @space.schedule_blocks.create!(
      day_of_week: 0,
      start_time: Time.zone.parse('2000-01-01 08:30'),
      end_time: Time.zone.parse('2000-01-01 09:00'),
      price_cents: 5000,
      position: 0
    )
    @space.schedule_blocks.create!(
      day_of_week: 0,
      start_time: Time.zone.parse('2000-01-01 09:00'),
      end_time: Time.zone.parse('2000-01-01 09:15'),
      price_cents: 2000,
      position: 1
    )

    schedule = AvailabilityScheduleBuilder.new(@space, week_start: @week_start).build
    monday = schedule.find { |day| day[:day_name] == 'Lunes' }

    assert_equal 2, monday[:slots].size
    assert_equal 30, ((monday[:slots][0].ends_at - monday[:slots][0].starts_at) / 60).to_i
    assert_equal 15, ((monday[:slots][1].ends_at - monday[:slots][1].starts_at) / 60).to_i
  end

  test 'omits slots after effective_until on template block' do
    future_monday = @week_start
    @space.schedule_blocks.for_day(0).update_all(effective_until: future_monday - 1.day)

    schedule = AvailabilityScheduleBuilder.new(@space, week_start: @week_start).build
    monday = schedule.find { |day| day[:date] == future_monday }

    assert_empty monday[:slots]
  end

  test 'build_weeks returns multiple weeks in one pass' do
    weeks = AvailabilityScheduleBuilder.new(@space, week_start: @week_start, week_count: 3).build_weeks

    assert_equal 3, weeks.size
    assert_equal @week_start, weeks.first[:week_start]
    assert_equal @week_start + 2.weeks, weeks.last[:week_start]
    weeks.each do |entry|
      assert_equal 7, entry[:schedule].size
    end
  end

  test 'build_weeks uses a bounded number of queries' do
    queries = []
    callback = lambda { |*, payload| queries << payload[:sql] if payload[:sql] }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      AvailabilityScheduleBuilder.new(@space, week_start: @week_start, week_count: 5).build_weeks
    end

    assert_operator queries.size, :<=, 10
  end
end
