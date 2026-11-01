# frozen_string_literal: true

require 'test_helper'

class BookingRescheduleTest < ActionDispatch::IntegrationTest
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
    @booking = result.booking
    @booking.update!(status: :confirmed, payment_expires_at: nil)
    sign_in @renter
  end

  test 'reschedule rejected when inside notice window' do
    @box.update_column(:reschedule_notice_hours, nil)
    SiteSetting.set('reschedule_notice_hours', '12')

    travel_to @start_at - 11.hours do
      patch reschedule_booking_path(@booking), params: {
        date: (@start_at + 7.days).to_date.to_s,
        start_time: @start_at.strftime('%H:%M'),
        slot_count: 2
      }
      assert_redirected_to root_path
      assert @booking.reload.confirmed?
    end
  end

  test 'reschedule succeeds when outside notice window' do
    @box.update_column(:reschedule_notice_hours, 1)
    new_start = @start_at + 7.days

    patch reschedule_booking_path(@booking), params: {
      date: new_start.to_date.to_s,
      start_time: new_start.strftime('%H:%M'),
      slot_count: 2
    }

    assert_redirected_to booking_path(Booking.order(:id).last)
    assert_match 'reprogramada', flash[:notice]
    assert @booking.reload.rescheduled?
  end

  test 'reschedule with price difference redirects to checkout' do
    @box.update_column(:reschedule_notice_hours, 1)
    new_start = @start_at + 7.days

    patch reschedule_booking_path(@booking), params: {
      date: new_start.to_date.to_s,
      start_time: new_start.strftime('%H:%M'),
      slot_count: 3
    }

    replacement = Booking.order(:id).last
    assert_redirected_to checkout_booking_path(replacement)
    assert_match 'diferencia', flash[:notice]
    assert @booking.reload.confirmed?
    assert replacement.pending_payment?
  end

  test 'confirmed booking shows pending reschedule alert on show page' do
    @box.update_column(:reschedule_notice_hours, 1)
    new_start = @start_at + 7.days
    Bookings::Reschedule.new(
      booking: @booking,
      actor: @renter,
      params: {
        date: new_start.to_date.to_s,
        start_time: new_start.strftime('%H:%M'),
        slot_count: 3
      }
    ).call

    get booking_path(@booking)

    assert_response :success
    assert_select 'p', text: /reagendamiento sin confirmar/
    assert_select 'a', text: 'Pagar diferencia y confirmar'
  end

  test 'show page includes interactive availability calendar for reschedule' do
    @box.update_column(:reschedule_notice_hours, 1)

    get booking_path(@booking)

    assert_response :success
    assert_select '[data-controller~="reschedule-form"]'
    assert_select '[data-controller~="availability-schedule"]'
    assert_match 'data-availability-schedule-form-controller-value="reschedule-form"', response.body
    assert_match 'Referencia: horarios por hora', response.body
    assert_select '[data-availability-schedule-target="content"][data-view="hora"]'
  end

  test 'availability json for reschedule booking' do
    @box.update_column(:reschedule_notice_hours, 1)

    get availability_booking_path(@booking), headers: { 'Accept' => 'application/json' }

    assert_response :success
    payload = JSON.parse(response.body)
    assert payload['weeks'].present?
    assert payload['interactive']
  end
end
