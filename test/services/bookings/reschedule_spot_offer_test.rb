# frozen_string_literal: true

require 'test_helper'

class BookingsRescheduleSpotOfferTest < ActiveSupport::TestCase
  setup do
    @box = boxes(:published_box)
    @box.update_column(:reschedule_notice_hours, 1)
    @profesional = users(:profesional)
    @admin = users(:admin)
    @offer = SpotOffer.create!(
      space: @box,
      created_by: @admin,
      profesional: @profesional,
      total_price_cents: 100_000,
      starts_on: Date.current,
      ends_on: Date.current + 30.days,
      daily_start_time: Time.zone.parse('08:00'),
      daily_end_time: Time.zone.parse('14:00'),
      status: :paid
    )
    start_at = 5.days.from_now.change(hour: 10)
    @booking = @offer.bookings.create!(
      space: @box,
      profesional: @profesional,
      start_at: start_at,
      end_at: start_at + 2.hours,
      duration_minutes: 120,
      booking_type: :hourly,
      status: :confirmed,
      total_amount_cents: 25_000,
      discount_cents: 0,
      pricing_breakdown: {}
    )
  end

  test 'profesional cannot reschedule spot offer booking' do
    service = Bookings::Reschedule.new(booking: @booking, actor: @profesional, params: {})
    assert_not service.rescheduleable?

    result = Bookings::Reschedule.new(
      booking: @booking,
      actor: @profesional,
      params: { date: 10.days.from_now.to_date.to_s, start_time: '10:00', hours: 2 }
    ).call
    assert_not result.success?
    assert_includes result.errors.join, 'administrador'
  end

  test 'admin can reschedule spot offer booking' do
    service = Bookings::Reschedule.new(booking: @booking, actor: @admin, params: {})
    assert service.rescheduleable?
  end
end
