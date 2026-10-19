# frozen_string_literal: true

require 'test_helper'

class DiscountCodeTest < ActiveSupport::TestCase
  test 'normalizes code on save' do
    code = DiscountCode.create!(
      code: '  verano 26 ',
      discount_type: :percent,
      percent: 15,
      starts_at: 1.day.ago,
      ends_at: 1.month.from_now
    )
    assert_equal 'VERANO26', code.code
  end

  test 'percent discount calculation' do
    code = DiscountCode.new(discount_type: :percent, percent: 10)
    assert_equal 1000, code.discount_cents_for(10_000)
  end

  test 'fixed discount is capped at payable' do
    code = DiscountCode.new(discount_type: :fixed_amount, amount_cents: 5000)
    assert_equal 3000, code.discount_cents_for(3000)
  end

  test 'applies_to_booking_type respects flags' do
    code = DiscountCode.new(applies_to_hourly: true, applies_to_slot_based: false, applies_to_jornada: false)
    assert code.applies_to_booking_type?(:hourly)
    assert_not code.applies_to_booking_type?(:slot_based)
    assert_not code.applies_to_booking_type?(:jornada)
  end
end
