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

    test 'marks slot blocked when schedule override blocks block' do
      block = schedule_blocks(:published_d0_h10)
      block.overrides.create!(space: @space, date: @slot_time.to_date, blocked: true)
      assert block.blocked_on?(@slot_time.to_date)

      days = AdminCalendarBuilder.new(space: @space, week_start: @week_start).build
      slot = days.flat_map { |d| d[:slots] }.find { |s| s.schedule_block_id == block.id }

      assert_equal :blocked, slot.status
    end

    private

    def create_booking!(start_at:, status:, payment_expires_at: nil)
      Booking.create!(
        space: @space,
        profesional: @renter,
        start_at: start_at,
        end_at: start_at + 2.hours,
        hours: 2,
        duration_minutes: 120,
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
