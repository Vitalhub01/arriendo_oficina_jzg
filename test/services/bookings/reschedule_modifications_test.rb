# frozen_string_literal: true

require 'test_helper'

class BookingsRescheduleModificationsTest < ActiveSupport::TestCase
  setup do
    @box = boxes(:published_box)
    @box.terms_and_conditions.purge if @box.terms_and_conditions.attached?
    @box.update_column(:reschedule_notice_hours, 1)
    @renter = users(:renter)
    @booking = create_confirmed_booking!(next_monday_at(hour: 10))
  end

  test 'allows up to three reschedules then blocks the fourth' do
    booking = @booking

    3.times do |i|
      new_start = booking.start_at + (7 + i).days
      result = reschedule!(booking, new_start)
      assert result.success?, result.errors.inspect
      booking = result.booking
      assert_equal i + 1, booking.reschedule_modifications_count
    end

    result = reschedule!(booking, booking.start_at + 30.days)
    assert_not result.success?
    assert_includes result.errors.join, 'límite de modificaciones'
    assert_equal 3, booking.reschedule_modifications_count
  end

  test 'modification limit applies to rescheduleable check' do
    @booking.update_column(:reschedule_modifications_count, 3)
    service = Bookings::Reschedule.new(booking: @booking, actor: @renter, params: {})
    assert_not service.rescheduleable?
  end

  private

  def create_confirmed_booking!(start_at)
    result = Bookings::Create.new(
      space: @box,
      profesional: @renter,
      params: {
        date: booking_date_param(start_at),
        start_time: booking_start_time_param(start_at),
        slot_count: 2
      }
    ).call
    raise result.errors.inspect unless result.success?

    booking = result.booking
    booking.update!(status: :confirmed, payment_expires_at: nil)
    booking
  end

  def reschedule!(booking, new_start)
    Bookings::Reschedule.new(
      booking: booking,
      actor: @renter,
      params: {
        date: new_start.to_date.to_s,
        start_time: new_start.strftime('%H:%M'),
        slot_count: 2
      }
    ).call
  end
end
