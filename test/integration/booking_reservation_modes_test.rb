# frozen_string_literal: true

require 'test_helper'

class BookingReservationModesTest < ActionDispatch::IntegrationTest
  setup do
    @space = boxes(:published_box)
    @space.update_column(:minimum_slots, 1)
    @space.terms_and_conditions.purge if @space.terms_and_conditions.attached?
    @renter = users(:renter)
    @slot_time = next_monday_at(hour: 10)
    ensure_bloque_pricing!
  end

  test 'hourly booking marks schedule slot unavailable and blocks duplicate create' do
    create_confirmed_hourly_booking!

    week_start = @slot_time.to_date.beginning_of_week(:monday)
    schedule = AvailabilityScheduleBuilder.new(@space, week_start: week_start).build
    monday = schedule.find { |day| day[:date] == @slot_time.to_date }
    slot_at_10 = monday[:slots].find { |s| s.starts_at.hour == 10 }

    assert slot_at_10, 'expected a 10:00 slot on Monday'
    assert_not slot_at_10.available

    result = Bookings::Create.new(
      space: @space,
      profesional: @renter,
      params: hourly_params(slot_count: 1)
    ).call

    assert_not result.success?
    assert_match(/no está disponible|Ya reservado/i, result.errors.join(' '))
  end

  test 'hourly booking blocks bloque reservation for same day' do
    create_confirmed_hourly_booking!
    morning = @space.bloque_slot_rates.find_by!(name: 'Mañana')
    checker = AvailabilityChecker.new(@space)

    assert_not checker.slot_rate_window_available?(@slot_time.to_date, morning)

    result = Bookings::Create.new(
      space: @space,
      profesional: @renter,
      params: {
        date: booking_date_param(@slot_time),
        reservation_mode: 'bloque',
        slot_rate_id: morning.id
      }
    ).call

    assert_not result.success?
  end

  test 'hourly booking blocks jornada reservation for same day' do
    create_confirmed_hourly_booking!
    jornada = @space.primary_jornada_definition
    checker = AvailabilityChecker.new(@space)

    assert_not checker.jornada_window_available?(@slot_time.to_date, jornada)

    result = Bookings::Create.new(
      space: @space,
      profesional: @renter,
      params: {
        date: booking_date_param(@slot_time),
        reservation_mode: 'jornada'
      }
    ).call

    assert_not result.success?
  end

  test 'cannot book same hour twice via HTTP' do
    sign_in @renter
    create_confirmed_hourly_booking!

    assert_no_difference 'Booking.count' do
      post space_bookings_path(@space), params: {
        date: booking_date_param(@slot_time),
        start_time: booking_start_time_param(@slot_time),
        slot_count: 1
      }
    end

    assert_response :unprocessable_entity
    assert_match 'ya no está disponible', response.body
  end

  private

  def ensure_bloque_pricing!
    Spaces::UpsertPricing.new(space: @space, params: admin_pricing_params).call
  end

  def hourly_params(slot_count: 1)
    {
      date: booking_date_param(@slot_time),
      start_time: booking_start_time_param(@slot_time),
      reservation_mode: 'hora',
      slot_count: slot_count
    }
  end

  def create_confirmed_hourly_booking!
    result = Bookings::Create.new(
      space: @space,
      profesional: @renter,
      params: hourly_params(slot_count: 1)
    ).call
    raise result.errors.inspect unless result.success?

    result.booking.update!(status: :confirmed, payment_expires_at: nil)
    result.booking
  end
end
