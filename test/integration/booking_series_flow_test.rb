# frozen_string_literal: true

require 'test_helper'

class BookingSeriesFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @box = boxes(:published_box)
    @renter = users(:renter)
    @starts_on = next_monday_at.to_date
    @ends_on = @starts_on + 8.weeks
    sign_in @renter
  end

  test 'creates series with initial bookings and enqueues job' do
    assert_difference 'BookingSeries.count', 1 do
      assert_difference 'Booking.count', 4 do
        assert_enqueued_with(job: GenerateSeriesBookingsJob) do
          post box_bookings_path(@box), params: series_params
        end
      end
    end

    assert_redirected_to bookings_path
    series = BookingSeries.order(:created_at).last
    assert series.active?
    assert series.bookings.all?(&:pending_payment?)
  end

  test 'job generates future bookings without duplicates' do
    post box_bookings_path(@box), params: series_params
    series = BookingSeries.order(:created_at).last
    initial_count = series.bookings.count

    perform_enqueued_jobs

    series.reload
    assert_operator series.bookings.count, :>, initial_count
    start_times = series.bookings.pluck(:start_at)
    assert_equal start_times.uniq.size, start_times.size
  end

  test 'rejects series when occurrences have conflicts' do
    conflict_date = @starts_on
    start_at = Time.zone.local(conflict_date.year, conflict_date.month, conflict_date.day, 7, 0)
    @box.bookings.create!(
      renter: @renter,
      start_at: start_at,
      end_at: start_at + 5.hours,
      hours: 5,
      total_amount_cents: @box.price_for_duration(5),
      status: :confirmed
    )

    assert_no_difference 'BookingSeries.count' do
      post box_bookings_path(@box), params: series_params(
        start_time: '07:00',
        hours: 5
      )
    end

    assert_response :unprocessable_entity
    assert_match 'conflictos', response.body
  end

  test 'series bookings appear in renter index' do
    post box_bookings_path(@box), params: series_params

    get bookings_path
    assert_response :success
    assert_match @box.title, response.body
    assert_match 'Pagar', response.body
  end

  test 'rejects series on day without availability rule' do
    assert_no_difference 'BookingSeries.count' do
      post box_bookings_path(@box), params: series_params(day_of_week: 5)
    end

    assert_response :unprocessable_entity
    assert_match 'Fuera del horario ofrecido', response.body
  end

  private

  def series_params(day_of_week: 0, start_time: '10:00', hours: 2)
    {
      booking_type: 'series',
      day_of_week: day_of_week,
      start_time: start_time,
      hours: hours,
      starts_on: @starts_on.to_s,
      ends_on: @ends_on.to_s
    }
  end
end
