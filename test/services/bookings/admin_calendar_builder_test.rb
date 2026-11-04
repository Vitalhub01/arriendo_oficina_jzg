# frozen_string_literal: true

require 'test_helper'

module Bookings
  class AdminCalendarBuilderTest < ActiveSupport::TestCase
    setup do
      @space = boxes(:published_box)
      @renter = users(:renter)
      @slot_time = next_monday_at(hour: 10)
      @week_start = @slot_time.to_date.beginning_of_week(:monday)
    end

    test 'marks slot available when no booking' do
      days = AdminCalendarBuilder.new(space: @space, week_start: @week_start).build
      slot = find_slot(days, @slot_time)

      assert slot
      assert_equal :available, slot.status
    end

    test 'marks slot confirmed when confirmed booking overlaps' do
      create_booking!(start_at: @slot_time, status: :confirmed)

      days = AdminCalendarBuilder.new(space: @space, week_start: @week_start).build
      slot = find_slot(days, @slot_time)

      assert_equal :confirmed, slot.status
      assert_includes slot.label, @renter.name
    end

    test 'marks slot pending when pending payment booking overlaps' do
      create_booking!(start_at: @slot_time, status: :pending_payment, payment_expires_at: 30.minutes.from_now)

      days = AdminCalendarBuilder.new(space: @space, week_start: @week_start).build
      slot = find_slot(days, @slot_time)

      assert_equal :pending, slot.status
    end

    test 'orders slots by start time when position values are out of order' do
      monday = @week_start
      @space.schedule_blocks.for_day(0).destroy_all
      [
        ['14:00', '15:00', 0],
        ['06:00', '07:00', 1],
        ['17:00', '18:00', 2]
      ].each do |start_label, end_label, position|
        @space.schedule_blocks.create!(
          day_of_week: 0,
          start_time: Time.zone.parse("2000-01-01 #{start_label}"),
          end_time: Time.zone.parse("2000-01-01 #{end_label}"),
          price_cents: 5000,
          position: position
        )
      end

      days = AdminCalendarBuilder.new(space: @space, week_start: @week_start).build
      day = days.find { |entry| entry[:date] == monday }
      hours = day[:slots].map { |slot| slot.starts_at.hour }

      assert_equal [6, 14, 17], hours
    end

    test 'marks slot blocked when schedule override blocks block' do
      block = schedule_blocks(:published_d0_h10)
      block.overrides.create!(space: @space, date: @slot_time.to_date, blocked: true)
      assert block.blocked_on?(@slot_time.to_date)

      days = AdminCalendarBuilder.new(space: @space, week_start: @week_start).build
      slot = days.flat_map { |d| d[:slots] }.find { |s| s.schedule_block_id == block.id }

      assert_equal :blocked, slot.status
      assert slot.unblockable
    end

    test 'marks slot cancelled when only cancelled booking overlaps' do
      create_booking!(start_at: @slot_time, status: :cancelled)

      days = AdminCalendarBuilder.new(space: @space, week_start: @week_start).build
      slot = find_slot(days, @slot_time)

      assert_equal :cancelled, slot.status
      assert_includes slot.label, 'Anulada'
    end

    test 'merges contiguous slots with the same confirmed booking' do
      create_booking!(start_at: @slot_time, end_at: @slot_time + 3.hours, status: :confirmed)

      days = AdminCalendarBuilder.new(space: @space, week_start: @week_start).build
      day = days.find { |entry| entry[:date] == @slot_time.to_date }
      confirmed = day[:slots].select { |s| s.status == :confirmed }

      assert_operator confirmed.size, :<, 3, 'expected fewer display slots than schedule blocks'
      span = confirmed.find { |s| s.starts_at.hour == @slot_time.hour }
      assert span
      assert_operator span.ends_at, :>, span.starts_at + 1.hour
    end

    private

    def create_booking!(start_at:, status:, end_at: nil, payment_expires_at: nil)
      finish = end_at || start_at + 2.hours
      duration = ((finish - start_at) / 60).to_i
      Booking.create!(
        space: @space,
        profesional: @renter,
        start_at: start_at,
        end_at: finish,
        hours: (duration / 60.0).ceil,
        duration_minutes: duration,
        total_amount_cents: 30_000,
        status: status,
        payment_expires_at: payment_expires_at,
        booking_type: :slot_based
      )
    end

    def find_slot(days, time)
      day = days.find { |d| d[:date] == time.to_date }
      day[:slots].find { |s| s.starts_at.hour == time.hour && s.starts_at.min == time.min }
    end
  end
end
