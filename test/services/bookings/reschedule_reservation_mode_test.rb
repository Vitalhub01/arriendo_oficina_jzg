# frozen_string_literal: true

require 'test_helper'

class BookingsRescheduleReservationModeTest < ActiveSupport::TestCase
  setup do
    @box = boxes(:published_box)
    @box.terms_and_conditions.purge if @box.terms_and_conditions.attached?
    @box.update_column(:reschedule_notice_hours, 1)
    @box.update_column(:minimum_slots, 1)
    @renter = users(:renter)
    ensure_bloque_pricing!
  end

  test 'jornada reschedule prices new day as jornada not hourly sum' do
    booking = create_jornada_booking!(next_monday_at(hour: 8))
    new_date = booking.start_at.to_date + 7.days

    result = reschedule!(booking, date: new_date)

    assert result.success?, result.errors.inspect
    assert_not result.requires_payment?, 'expected no payment when jornada price matches credit'
    replacement = result.booking
    assert replacement.confirmed?
    assert replacement.jornada?
    assert_equal 'jornada', replacement.pricing_breakdown['reservation_mode']
    assert_equal 0, replacement.total_amount_cents
    assert_match(/Jornada completa/i, replacement.pricing_breakdown['breakdown'].first['label'])
  end

  test 'bloque reschedule keeps block pricing' do
    morning = @box.bloque_slot_rates.find_by!(name: 'Mañana')
    date = next_monday_at(hour: 8).to_date
    booking = create_bloque_booking!(date, morning)
    new_date = date + 7.days

    result = reschedule!(booking, date: new_date, slot_rate_id: morning.id)

    assert result.success?, result.errors.inspect
    replacement = result.booking
    assert_equal 'bloque', replacement.pricing_breakdown['reservation_mode']
    assert_equal morning.id, replacement.pricing_breakdown['slot_rate_id']
    assert_equal morning.block_price_cents_effective, replacement.pricing_breakdown['subtotal_cents']
    assert_equal 0, replacement.total_amount_cents
  end

  test 'bloque reschedule to different block on same day charges block price difference only' do
    morning = @box.bloque_slot_rates.find_by!(name: 'Mañana')
    afternoon = @box.bloque_slot_rates.find_by!(name: 'Tarde')
    date = next_monday_at(hour: 8).to_date
    booking = create_bloque_booking!(date, morning)

    result = reschedule!(booking, date: date, slot_rate_id: afternoon.id)

    assert result.success?, result.errors.inspect
    replacement = result.booking
    expected_due = afternoon.block_price_cents_effective - morning.block_price_cents_effective
    assert_equal expected_due, replacement.total_amount_cents
    assert result.requires_payment? if expected_due.positive?
  end

  private

  def ensure_bloque_pricing!
    Spaces::UpsertPricing.new(space: @box, params: admin_pricing_params).call
  end

  def create_jornada_booking!(start_anchor)
    date = start_anchor.to_date
    result = Bookings::Create.new(
      space: @box,
      profesional: @renter,
      params: { date: date.to_s, reservation_mode: 'jornada' }
    ).call
    raise result.errors.inspect unless result.success?

    booking = result.booking
    booking.update!(status: :confirmed, payment_expires_at: nil)
    booking
  end

  def create_bloque_booking!(date, slot_rate)
    result = Bookings::Create.new(
      space: @box,
      profesional: @renter,
      params: {
        date: date.to_s,
        reservation_mode: 'bloque',
        slot_rate_id: slot_rate.id
      }
    ).call
    raise result.errors.inspect unless result.success?

    booking = result.booking
    booking.update!(status: :confirmed, payment_expires_at: nil)
    booking
  end

  def reschedule!(booking, date:, slot_rate_id: nil)
    params = { date: date.to_s, reservation_mode: booking.reschedule_reservation_mode }
    params[:slot_rate_id] = slot_rate_id if slot_rate_id
    if booking.reschedule_reservation_mode == 'hora'
      params[:start_time] = booking.start_at.strftime('%H:%M')
      params[:slot_count] = booking.slot_count
    end

    Bookings::Reschedule.new(booking: booking, actor: @renter, params: params).call
  end
end
