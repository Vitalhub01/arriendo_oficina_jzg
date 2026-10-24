# frozen_string_literal: true

require 'test_helper'

class BookingsRescheduleNoticeTest < ActiveSupport::TestCase
  setup do
    @box = boxes(:published_box)
    @box.terms_and_conditions.purge if @box.terms_and_conditions.attached?
    @renter = users(:renter)
    @start_at = next_monday_at(hour: 10)
    result = Bookings::Create.new(
      space: @box,
      profesional: @renter,
      params: {
        date: booking_date_param(@start_at),
        start_time: booking_start_time_param(@start_at),
        slot_count: 2
      }
    ).call
    raise result.errors.inspect unless result.success?

    @booking = result.booking
    @booking.update!(status: :confirmed, payment_expires_at: nil)
  end

  test 'default notice is twelve hours without space override' do
    @box.update_column(:reschedule_notice_hours, nil)
    SiteSetting.set('reschedule_notice_hours', '12')

    travel_to Time.zone.local(2026, 6, 1, 10, 0) do
      too_soon = 11.hours.from_now
      @booking.update_columns(start_at: too_soon, end_at: too_soon + 2.hours)
      service = Bookings::Reschedule.new(booking: @booking, actor: @renter, params: {})
      assert_not service.rescheduleable?

      in_time = 13.hours.from_now
      @booking.update_columns(start_at: in_time, end_at: in_time + 2.hours)
      service = Bookings::Reschedule.new(booking: @booking.reload, actor: @renter, params: {})
      assert service.rescheduleable?
    end
  end

  test 'uses space reschedule notice hours when set' do
    future_start = 48.hours.from_now.change(min: 0)
    @booking.update_columns(start_at: future_start, end_at: future_start + 2.hours)

    @box.update_column(:reschedule_notice_hours, 72)

    service = Bookings::Reschedule.new(booking: @booking, actor: @renter, params: {})
    assert_not service.rescheduleable?

    @box.update_column(:reschedule_notice_hours, 24)
    service = Bookings::Reschedule.new(booking: @booking, actor: @renter, params: {})
    assert service.rescheduleable?
  end

  test 'rescheduling frees previous slot' do
    @box.update_column(:reschedule_notice_hours, 1)
    new_start = @start_at + 7.days

    result = Bookings::Reschedule.new(
      booking: @booking,
      actor: @renter,
      params: {
        date: new_start.to_date.to_s,
        start_time: new_start.strftime('%H:%M'),
        slot_count: 2
      }
    ).call

    assert result.success?, result.errors.inspect
    assert @booking.reload.rescheduled?
    assert result.booking.confirmed?
    assert_equal 1, result.booking.reschedule_modifications_count
    assert_not Booking.blocking_availability.exists?(@booking.id)
  end
end
