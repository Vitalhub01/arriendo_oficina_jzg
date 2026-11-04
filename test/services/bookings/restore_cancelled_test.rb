# frozen_string_literal: true

require 'test_helper'

module Bookings
  class RestoreCancelledTest < ActiveSupport::TestCase
    setup do
      @space = boxes(:published_box)
      @admin = users(:admin)
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

    test 'admin restores cancelled booking when slot is free' do
      result = RestoreCancelled.new(booking: @booking, actor: @admin).call

      assert result.success?
      assert @booking.reload.confirmed?
    end

    test 'fails when another booking blocks the slot' do
      Booking.create!(
        space: @space,
        profesional: @renter,
        start_at: @start_at,
        end_at: @start_at + 2.hours,
        hours: 2,
        duration_minutes: 120,
        total_amount_cents: 30_000,
        status: :confirmed,
        booking_type: :slot_based
      )

      result = RestoreCancelled.new(booking: @booking, actor: @admin).call

      assert_not result.success?
      assert @booking.reload.cancelled?
    end
  end
end
