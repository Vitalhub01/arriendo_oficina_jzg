# frozen_string_literal: true

require 'test_helper'

module ScheduleBlocks
  class BookingGuardTest < ActiveSupport::TestCase
    setup do
      @space = boxes(:published_box)
      @start_at = next_monday_at(hour: 9)
    end

    test 'detects confirmed booking overlapping template block' do
      booking = create_blocking_booking!(@start_at)
      block = overlapping_template_block(booking)
      assert block, 'expected a template block for the booking slot'

      assert BookingGuard.overlaps?(booking, block)
      assert BookingGuard.protected?(@space, block)
    end

    test 'ignores cancelled bookings' do
      booking = create_blocking_booking!(@start_at)
      block = overlapping_template_block(booking)
      booking.update!(status: :cancelled)

      assert_not BookingGuard.protected?(@space, block)
    end

    test 'ignores bookings on other weekdays' do
      tuesday = @start_at + 1.day
      booking = create_blocking_booking!(tuesday)
      monday_block = @space.schedule_blocks.for_day(0).first

      assert_not BookingGuard.overlaps?(booking, monday_block)
    end

    private

    def create_blocking_booking!(start_at)
      result = Bookings::Create.new(
        space: @space,
        profesional: users(:renter),
        params: {
          date: start_at.to_date.to_s,
          start_time: start_at.strftime('%H:%M'),
          slot_count: 2
        }
      ).call
      assert result.success?, result.errors.inspect

      booking = result.booking
      booking.update!(status: :confirmed, payment_expires_at: nil)
      booking
    end

    def overlapping_template_block(booking)
      day = (booking.start_at.wday + 6) % 7
      @space.schedule_blocks.for_day(day).find { |block| BookingGuard.overlaps?(booking, block) }
    end
  end
end
