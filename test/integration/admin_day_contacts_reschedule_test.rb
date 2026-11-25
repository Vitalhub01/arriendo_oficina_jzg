# frozen_string_literal: true

require 'test_helper'

# Escenario tipo producción: dos profesionales distintos en el mismo box el mismo día,
# con horarios que se cruzan en pantalla (p. ej. reprogramada + confirmada en franjas que se cruzan).
class AdminDayContactsRescheduleTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @renter = users(:renter)
    @box = boxes(:published_box)
    @box.terms_and_conditions.purge if @box.terms_and_conditions.attached?
    @box.update_column(:reschedule_notice_hours, 1)
    @original_start = next_monday_at(hour: 10)
  end

  test 'day contacts lists only blocking booking after same day reschedule' do
    sign_in @admin
    booking = create_confirmed_booking!(@original_start, slot_count: 2)
    new_start = @original_start + 2.hours
    assert_equal @original_start.to_date, new_start.to_date
    assert_not_equal booking.start_at, new_start

    result = reschedule!(booking, new_start, slot_count: 2)
    assert result.success?, result.errors.inspect
    assert booking.reload.rescheduled?
    assert result.booking.confirmed?

    get day_contacts_admin_bookings_path, params: { date: @original_start.to_date.iso8601 }
    assert_response :success

    assert_select 'li', text: /Reprogramada/, count: 0
    assert_select 'li', text: /Confirmada/, minimum: 1

    blocking = @box.bookings.blocking_availability.starting_on_date(@original_start.to_date)
    assert_equal 1, blocking.count, 'solo la reserva confirmada debe bloquear disponibilidad'
    assert blocking.exists?(id: result.booking.id)
    assert_not blocking.exists?(id: booking.id)
  end

  test 'rejects overlapping reschedule on same day while original is still confirmed' do
    booking = create_confirmed_booking!(@original_start, slot_count: 2)
    result = reschedule!(booking, @original_start, slot_count: 3)

    assert_not result.success?, 'no debería permitir franja que solapa con la reserva vigente'
    assert booking.reload.confirmed?, 'la original sigue confirmada si falló el reagendamiento'
  end

  test 'box cannot have two blocking bookings with overlapping intervals' do
    create_confirmed_booking!(@original_start, slot_count: 2)
    other_start = @original_start + 3.hours
    create_confirmed_booking!(other_start, slot_count: 2)

    assert_equal 2, @box.bookings.blocking_availability.starting_on_date(@original_start.to_date).count

    overlaps = @box.bookings.blocking_availability
                   .starting_on_date(@original_start.to_date)
                   .to_a
                   .combination(2)
                   .any? do |a, b|
      a.start_at < b.end_at && a.end_at > b.start_at
    end
    assert_not overlaps, 'no debe haber pares de reservas bloqueantes solapadas en el mismo box'
  end

  test 'second professional can book overlapping slot after first is marked rescheduled' do
    paula = users(:renter)
    romina = users(:profesional)
    slot_start = next_monday_at(hour: 10)

    paula_booking = create_confirmed_booking!(slot_start, slot_count: 2, profesional: paula)

    new_start = slot_start + 7.days
    result = Bookings::Reschedule.new(
      booking: paula_booking,
      actor: paula,
      params: {
        date: new_start.to_date.to_s,
        start_time: new_start.strftime('%H:%M'),
        slot_count: 2
      }
    ).call
    assert result.success?, result.errors.inspect
    assert paula_booking.reload.rescheduled?

    romina_result = Bookings::Create.new(
      space: @box,
      profesional: romina,
      params: {
        date: booking_date_param(slot_start),
        start_time: booking_start_time_param(slot_start),
        slot_count: 2
      },
      require_terms_acceptance: false
    ).call
    assert romina_result.success?, romina_result.errors.inspect
    romina_booking = romina_result.booking
    romina_booking.update!(status: :confirmed, payment_expires_at: nil)

    assert romina_booking.start_at < paula_booking.end_at
    assert romina_booking.end_at > paula_booking.start_at,
           'los intervalos se cruzan en el reloj aunque solo una reserva bloquee'

    blocking = @box.bookings.blocking_availability.starting_on_date(slot_start.to_date)
    assert blocking.exists?(id: romina_booking.id)
    assert_not blocking.exists?(id: paula_booking.id)

    sign_in @admin
    get day_contacts_admin_bookings_path, params: { date: slot_start.to_date.iso8601 }
    assert_response :success
    assert_select 'li', text: /Reprogramada/, count: 0
    assert_match romina.email, response.body
    assert_no_match paula.email, response.body
  end

  test 'admin booking show explains rescheduled booking and links successor' do
    sign_in @admin
    booking = create_confirmed_booking!(@original_start, slot_count: 2)
    new_start = @original_start + 7.days
    result = reschedule!(booking, new_start, slot_count: 2)
    assert result.success?, result.errors.inspect
    assert booking.reload.rescheduled?

    get admin_booking_path(booking)
    assert_response :success
    assert_select '.border-blue-200', text: /fue reprogramada/i
    assert_select 'a[href=?]', admin_booking_path(result.booking), text: /Ver reserva ##{result.booking.id}/
  end

  private

  def create_confirmed_booking!(start_at, slot_count:, profesional: @renter)
    result = Bookings::Create.new(
      space: @box,
      profesional: profesional,
      params: {
        date: booking_date_param(start_at),
        start_time: booking_start_time_param(start_at),
        slot_count: slot_count
      },
      require_terms_acceptance: false
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