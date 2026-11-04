# frozen_string_literal: true

require 'test_helper'

class DiscountCodeRestrictionsTest < ActiveSupport::TestCase
  setup do
    @space = boxes(:published_box)
    @other_space = boxes(:draft_box)
    @renter = users(:renter)
    @monday_morning = next_monday_at(hour: 10)
  end

  def build_booking(start_at:, end_at: @monday_morning + 2.hours, space: @space)
    Booking.new(
      space: space,
      profesional: @renter,
      start_at: start_at,
      end_at: end_at,
      hours: 2,
      duration_minutes: 120,
      status: :pending_payment,
      booking_type: :slot_based
    )
  end

  def create_code(**attrs)
    DiscountCode.create!(
      {
        code: "T#{SecureRandom.hex(3).upcase}",
        discount_type: :percent,
        percent: 10,
        starts_at: 1.day.ago,
        ends_at: 1.month.from_now
      }.merge(attrs)
    )
  end

  test 'example 1 fixed amount once per user' do
    code = create_code(discount_type: :fixed_amount, amount_cents: 2000, max_uses_per_user: 1)
    booking = build_booking(start_at: @monday_morning)

    assert code.within_user_use_limit?(@renter.id)
    assert_equal 2000, code.discount_cents_for(5000)

    Booking.create!(
      booking.attributes.except('id').merge(
        discount_code: code,
        payment_expires_at: 30.minutes.from_now,
        total_amount_cents: 3000
      )
    )

    assert_not code.within_user_use_limit?(@renter.id)
  end

  test 'example 2 percent until end date uses existing vigencia' do
    code = create_code(ends_at: Time.zone.local(2026, 12, 31, 23, 59))
    assert code.redeemable_at?(Time.zone.local(2026, 12, 15, 12))
    assert_not code.redeemable_at?(Time.zone.local(2027, 1, 1, 0))
  end

  test 'example 3 global max uses' do
    code = create_code(max_uses: 100, redemptions_count: 99)
    assert code.redeemable_at?
    code.update!(redemptions_count: 100)
    assert_not code.redeemable_at?
  end

  test 'example 4 ten uses thursdays only' do
    code = create_code(max_uses: 10, allowed_weekdays: [3])
    thursday = @monday_morning + 3.days
    friday = thursday + 1.day

    assert code.applies_to_booking_schedule?(build_booking(start_at: thursday, end_at: thursday + 2.hours))
    assert_not code.applies_to_booking_schedule?(build_booking(start_at: friday, end_at: friday + 2.hours))
  end

  test 'example 5 weekdays mon wed morning window' do
    code = create_code(
      allowed_weekdays: [0, 1, 2],
      allowed_start_time: '08:00',
      allowed_end_time: '12:00'
    )

    monday_ok = build_booking(start_at: next_monday_at(hour: 9), end_at: next_monday_at(hour: 11))
    monday_late = build_booking(start_at: next_monday_at(hour: 11), end_at: next_monday_at(hour: 13))
    thursday = build_booking(start_at: next_monday_at(hour: 9) + 3.days, end_at: next_monday_at(hour: 11) + 3.days)

    assert code.applies_to_booking_schedule?(monday_ok)
    assert_not code.applies_to_booking_schedule?(monday_late)
    assert_not code.applies_to_booking_schedule?(thursday)
  end

  test 'example 6 combined limits spaces and friday saturday mornings' do
    code = create_code(
      max_uses: 10,
      max_uses_per_user: 1,
      allowed_weekdays: [4, 5],
      allowed_start_time: '08:00',
      allowed_end_time: '12:00',
      allowed_space_ids: [@space.id]
    )

    friday_morning = build_booking(
      start_at: next_monday_at(hour: 9) + 4.days,
      end_at: next_monday_at(hour: 11) + 4.days,
      space: @space
    )
    friday_wrong_space = build_booking(
      start_at: next_monday_at(hour: 9) + 4.days,
      end_at: next_monday_at(hour: 11) + 4.days,
      space: @other_space
    )

    assert code.applies_to_booking?(friday_morning)
    assert_not code.applies_to_booking_space?(friday_wrong_space)
  end

  test 'single time window requires full containment' do
    code = create_code(
      allowed_start_time: '10:00',
      allowed_end_time: '11:00'
    )

    slot_10_11 = build_booking(start_at: next_monday_at(hour: 10), end_at: next_monday_at(hour: 11))
    slot_10_12 = build_booking(start_at: next_monday_at(hour: 10), end_at: next_monday_at(hour: 12))

    assert code.applies_to_booking_schedule?(slot_10_11)
    assert_not code.applies_to_booking_schedule?(slot_10_12)
  end

  test 'confirmed bookings count' do
    code = create_code
    Booking.create!(
      space: @space,
      profesional: @renter,
      start_at: @monday_morning,
      end_at: @monday_morning + 2.hours,
      hours: 2,
      duration_minutes: 120,
      status: :confirmed,
      booking_type: :slot_based,
      discount_code: code,
      total_amount_cents: 1000
    )

    assert_equal 1, code.confirmed_bookings_count
  end
end
