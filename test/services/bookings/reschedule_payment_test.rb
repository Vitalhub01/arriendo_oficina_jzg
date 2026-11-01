# frozen_string_literal: true

require 'test_helper'

class BookingsReschedulePaymentTest < ActiveSupport::TestCase
  setup do
    @box = boxes(:published_box)
    @box.terms_and_conditions.purge if @box.terms_and_conditions.attached?
    @box.update_column(:reschedule_notice_hours, 1)
    @renter = users(:renter)
    @start_at = next_monday_at(hour: 10)
    @booking = create_confirmed_booking!(@start_at, slot_count: 2)
  end

  test 'pending price difference keeps original booking confirmed' do
    new_start = @start_at + 7.days

    result = reschedule!(@booking, new_start, slot_count: 3)

    assert result.success?, result.errors.inspect
    assert result.requires_payment?
    assert @booking.reload.confirmed?
    assert result.booking.pending_payment?
    assert result.booking.total_amount_cents.positive?
  end

  test 'cancelling pending replacement restores original schedule' do
    new_start = @start_at + 7.days
    result = reschedule!(@booking, new_start, slot_count: 3)
    replacement = result.booking

    cancel = Bookings::Cancel.new(booking: replacement, actor: @renter).call
    assert cancel.success?

    assert @booking.reload.confirmed?
    assert replacement.reload.cancelled?
    assert_nil replacement.reschedule_credit_id
    assert_not RescheduleCredit.exists?(source_booking_id: @booking.id)
  end

  test 'confirming replacement marks original as rescheduled' do
    new_start = @start_at + 7.days
    result = reschedule!(@booking, new_start, slot_count: 3)
    replacement = result.booking

    replacement.update!(status: :confirmed, payment_expires_at: nil)
    Bookings::FinalizeReschedule.new(booking: replacement).call

    assert @booking.reload.rescheduled?
    assert replacement.confirmed?
    assert_equal 1, replacement.reschedule_modifications_count
  end

  test 'rejects reschedule on the same calendar date as the booking' do
    same_day = Time.zone.local(@start_at.year, @start_at.month, @start_at.day, 11, 0)
    assert_equal @start_at.to_date, same_day.to_date

    result = reschedule!(@booking, same_day, slot_count: 2)

    assert_not result.success?
    assert_includes result.errors.join, 'fecha distinta'
    assert @booking.reload.confirmed?
  end

  test 'same duration after promo does not require extra payment' do
    subtotal = @booking.pricing_breakdown['subtotal_cents']
    promo = (subtotal * 0.1).round
    @booking.update!(
      promo_discount_cents: promo,
      total_amount_cents: subtotal - promo
    )

    new_start = @start_at + 7.days
    result = reschedule!(@booking, new_start, slot_count: 2)

    assert result.success?, result.errors.inspect
    assert_not result.requires_payment?
    assert result.booking.confirmed?
    assert_equal 0, result.booking.total_amount_cents
    assert @booking.reload.rescheduled?
  end

  private

  def create_confirmed_booking!(start_at, slot_count:)
    result = Bookings::Create.new(
      space: @box,
      profesional: @renter,
      params: {
        date: booking_date_param(start_at),
        start_time: booking_start_time_param(start_at),
        slot_count: slot_count
      }
    ).call
    raise result.errors.inspect unless result.success?

    booking = result.booking
    booking.update!(status: :confirmed, payment_expires_at: nil)
    booking
  end

  def reschedule!(booking, new_start, slot_count:)
    Bookings::Reschedule.new(
      booking: booking,
      actor: @renter,
      params: {
        date: new_start.to_date.to_s,
        start_time: new_start.strftime('%H:%M'),
        slot_count: slot_count
      }
    ).call
  end
end
