# frozen_string_literal: true

require 'test_helper'

class UserTestimonialFlowTest < ActionDispatch::IntegrationTest
  include IntegrationHelpers

  setup do
    @renter = users(:renter)
    @box = boxes(:published_box)
    @slot_time = next_monday_at(hour: 10)
  end

  test 'guest cannot access comment form' do
    get new_user_testimonial_path
    assert_redirected_to new_user_session_path
  end

  test 'user without bookings cannot access comment form' do
    sign_in users(:profesional)
    get new_user_testimonial_path
    assert_redirected_to root_path
  end

  test 'user with booking can submit free comment' do
    sign_in @renter
    create_booking_for_renter

    get new_user_testimonial_path
    assert_response :success
    assert_match 'Tu comentario', response.body

    assert_difference 'Testimonial.general.count', 1 do
      post user_testimonial_path, params: { testimonial: { body: 'Excelente espacio y atención.' } }
    end

    testimonial = Testimonial.general.last
    assert_equal @renter.id, testimonial.profesional_id
    assert_not testimonial.visible?
    assert_redirected_to new_user_testimonial_path
    follow_redirect!
    assert_match 'Excelente espacio', response.body
  end

  private

  def create_booking_for_renter
    Booking.create!(
      space: @box,
      profesional: @renter,
      start_at: @slot_time,
      end_at: @slot_time + 2.hours,
      hours: 2,
      duration_minutes: 120,
      total_amount_cents: @box.default_price_per_slot_cents * 2,
      status: :confirmed,
      booking_type: :slot_based
    )
  end
end
