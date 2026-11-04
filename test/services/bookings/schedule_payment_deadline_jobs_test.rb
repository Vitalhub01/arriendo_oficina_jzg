# frozen_string_literal: true

require 'test_helper'

module Bookings
  class SchedulePaymentDeadlineJobsTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @box = boxes(:published_box)
      @renter = users(:renter)
      @slot_time = next_monday_at(hour: 10)
    end

    test 'enqueues expire and reminder jobs when booking needs payment' do
      expires_at = 30.minutes.from_now

      assert_enqueued_with(job: ExpirePendingJob, at: expires_at) do
        assert_enqueued_with(job: PaymentExpiryReminderJob, at: expires_at - 20.minutes) do
          Bookings::SchedulePaymentDeadlineJobs.call(
            Booking.new(
              id: 99,
              status: :pending_payment,
              payment_expires_at: expires_at,
              total_amount_cents: 10_000
            )
          )
        end
      end
    end

    test 'does not enqueue for free bookings' do
      assert_no_enqueued_jobs only: [ExpirePendingJob, PaymentExpiryReminderJob] do
        Bookings::SchedulePaymentDeadlineJobs.call(
          Booking.new(
            status: :pending_payment,
            payment_expires_at: 30.minutes.from_now,
            total_amount_cents: 0
          )
        )
      end
    end

    test 'schedules jobs after create when payment is required' do
      expires_at = 30.minutes.from_now

      assert_enqueued_jobs 2, only: [ExpirePendingJob, PaymentExpiryReminderJob] do
        Booking.create!(
          space: @box,
          profesional: @renter,
          start_at: @slot_time,
          end_at: @slot_time + 2.hours,
          hours: 2,
          duration_minutes: 120,
          total_amount_cents: @box.default_price_per_slot_cents * 2,
          status: :pending_payment,
          payment_expires_at: expires_at,
          booking_type: :slot_based
        )
      end
    end
  end
end
