# frozen_string_literal: true

require 'test_helper'

module Bookings
  class ApplyDiscountCodeTest < ActiveSupport::TestCase
    setup do
      @box = boxes(:published_box)
      @renter = users(:renter)
      slot_time = next_monday_at(hour: 10)
      @booking = Booking.create!(
        space: @box,
        profesional: @renter,
        start_at: slot_time,
        end_at: slot_time + 2.hours,
        hours: 2,
        duration_minutes: 120,
        status: :pending_payment,
        payment_expires_at: 30.minutes.from_now,
        booking_type: :slot_based
      )
      @code = DiscountCode.create!(
        code: 'PROMO10',
        discount_type: :percent,
        percent: 10,
        starts_at: 1.day.ago,
        ends_at: 1.month.from_now
      )
    end

    test 'applies percent code and reduces total' do
      payable = @booking.total_amount_cents
      result = ApplyDiscountCode.new(booking: @booking, code: 'promo10', actor: @renter).call

      assert result.success?
      @booking.reload
      assert_equal @code.id, @booking.discount_code_id
      assert_equal (payable * 0.1).round, @booking.promo_discount_cents
      assert_equal payable - @booking.promo_discount_cents, @booking.total_amount_cents
      assert_equal 1, @code.reload.redemptions_count
    end

    test 'rejects expired code' do
      @code.update!(ends_at: 1.hour.ago)
      payable = @booking.total_amount_cents

      result = ApplyDiscountCode.new(booking: @booking, code: 'PROMO10', actor: @renter).call

      assert_not result.success?
      assert_equal payable, @booking.reload.total_amount_cents
    end

    test 'rejects code when booking type is not allowed' do
      @code.update!(applies_to_slot_based: false)
      payable = @booking.total_amount_cents

      result = ApplyDiscountCode.new(booking: @booking, code: 'PROMO10', actor: @renter).call

      assert_not result.success?
      assert_includes result.errors, 'El código no es válido para el tipo de reserva'
      assert_equal payable, @booking.reload.total_amount_cents
    end

    test 'rejects code outside allowed schedule' do
      @code.update!(allowed_start_time: '08:00', allowed_end_time: '09:00')
      result = ApplyDiscountCode.new(booking: @booking, code: 'PROMO10', actor: @renter).call

      assert_not result.success?
      assert_includes result.errors, 'El código no aplica al día u horario de esta reserva'
    end

    test 'rejects when user exceeded per-user limit' do
      @code.update!(max_uses_per_user: 1)
      other = Booking.create!(
        space: @box,
        profesional: @renter,
        start_at: @booking.start_at + 1.day,
        end_at: @booking.end_at + 1.day,
        hours: 2,
        duration_minutes: 120,
        status: :pending_payment,
        payment_expires_at: 30.minutes.from_now,
        booking_type: :slot_based,
        discount_code: @code
      )
      assert other.persisted?

      result = ApplyDiscountCode.new(booking: @booking, code: 'PROMO10', actor: @renter).call

      assert_not result.success?
      assert_includes result.errors, 'Ya alcanzaste el máximo de usos de este código'
    end
  end
end
