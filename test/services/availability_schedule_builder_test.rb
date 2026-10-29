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

  test 'exclude_renter_id omits that users pending booking from availability' do
    renter = users(:renter)
    slot_time = @week_start.to_time.change(hour: 10)
    Booking.create!(
      space: @space,
      profesional: renter,
      start_at: slot_time,
      end_at: slot_time + 2.hours,
      duration_minutes: 120,
      status: :pending_payment,
      payment_expires_at: 30.minutes.from_now,
      total_amount_cents: 20_000,
      booking_type: :slot_based
    )

    without_exclude = AvailabilityScheduleBuilder.new(@space, week_start: @week_start).build
    monday_blocked = without_exclude.find { |day| day[:date] == @week_start }
    ten_am_blocked = monday_blocked[:slots].find { |s| s.starts_at.hour == 10 }
    assert_not ten_am_blocked.available

    with_exclude = AvailabilityScheduleBuilder.new(
      @space,
      week_start: @week_start,
      exclude_renter_id: renter.id
    ).build
    monday_open = with_exclude.find { |day| day[:date] == @week_start }
    ten_am_open = monday_open[:slots].find { |s| s.starts_at.hour == 10 }
    assert ten_am_open.available
  end

  test 'build_weeks uses a bounded number of queries' do
    queries = []
    callback = lambda { |*, payload| queries << payload[:sql] if payload[:sql] }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      AvailabilityScheduleBuilder.new(@space, week_start: @week_start, week_count: 5).build_weeks
    end

    assert_operator queries.size, :<=, 12
  end

  test 'bloque and jornada entries match AvailabilityChecker' do
    week_start = next_monday_at(hour: 10).to_date.beginning_of_week(:monday)
    date = next_monday_at(hour: 10).to_date
    checker = AvailabilityChecker.new(@space)

    schedule = AvailabilityScheduleBuilder.new(@space, week_start: week_start, week_count: 1).build
    day = schedule.find { |entry| entry[:date] == date }

    day[:bloque].each do |entry|
      assert_equal checker.slot_rate_window_available?(date, entry[:rate]), entry[:available],
                   "bloque #{entry[:rate].name} availability mismatch"
    end

    jornada_entry = day[:jornada]
    if jornada_entry
      assert_equal checker.jornada_window_available?(date, jornada_entry[:jornada]), jornada_entry[:available]
    end
  end

  test 'bloque entries reflect booking conflicts without extra queries' do
    date = next_monday_at(hour: 10).to_date
    week_start = date.beginning_of_week(:monday)
    slot_time = Time.zone.local(date.year, date.month, date.day, 10, 0)
    morning = @space.bloque_slot_rates.first

    Booking.create!(
      space: @space,
      profesional: users(:renter),
      start_at: slot_time,
      end_at: slot_time + 2.hours,
      duration_minutes: 120,
      status: :confirmed,
      total_amount_cents: 20_000,
      booking_type: :slot_based
    )

    day = AvailabilityScheduleBuilder.new(@space, week_start: week_start).build.find { |d| d[:date] == date }
    morning_entry = day[:bloque].find { |e| e[:rate].id == morning.id }

    assert_not morning_entry[:available]
  end
end
