# frozen_string_literal: true

require 'test_helper'

module Bookings
  class DismissFromAdminCalendarTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin)
      @space = boxes(:published_box)
      @renter = users(:renter)
      @start_at = next_monday_at(hour: 10)
      @booking = Booking.create!(
        space: @space,
        profesional: @renter,
        start_at: @start_at,
        end_at: @start_at + 2.hours,
        hours: 2,
        duration_minutes: 120,
        total_amount_cents: 30_000,
        status: :cancelled,
        booking_type: :slot_based
      )
    end

    test 'admin hides cancelled booking from admin calendar' do
      result = DismissFromAdminCalendar.new(booking: @booking, actor: @admin).call

      assert result.success?
      assert DismissFromAdminCalendar.hidden?(@booking.reload)
    end

    test 'rejects non cancelled booking' do
      @booking.update!(status: :confirmed)

      result = DismissFromAdminCalendar.new(booking: @booking, actor: @admin).call

      assert_not result.success?
    end
  end
end
