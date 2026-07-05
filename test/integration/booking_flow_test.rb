# frozen_string_literal: true

require 'test_helper'

class BookingFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @box = boxes(:published_box)
    @renter = users(:renter)
    @owner = users(:owner)
    @slot_time = next_monday_at(hour: 10)
  end

  test 'booking requires authentication' do
    post box_bookings_path(@box), params: booking_params
    assert_redirected_to new_user_session_path
  end

  test 'creates pending booking with expiry and redirects to checkout' do
    sign_in @renter

    assert_difference 'Booking.count', 1 do
      assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
        post box_bookings_path(@box), params: booking_params
      end
    end

    booking = Booking.order(:created_at).last
    assert booking.pending_payment?
    assert booking.payment_expires_at.present?
    assert_equal 2, booking.hours
    assert_redirected_to checkout_booking_path(booking)
  end

  test 'checkout creates payment and redirects to mercado pago' do
    sign_in @renter
    booking = create_pending_booking

    with_mercadopago_stub do
      assert_difference 'Payment.count', 1 do
        get checkout_booking_path(booking)
      end
    end

    payment = booking.reload.payment
    assert payment.pending?
    assert_equal 'TEST-pref-1', payment.mercadopago_preference_id
    assert_redirected_to 'https://sandbox.mercadopago.cl/checkout'
  end

  test 'checkout reuses pending payment' do
    sign_in @renter
    booking = create_pending_booking
    create_payment_for(booking)

    with_mercadopago_stub do
      assert_no_difference 'Payment.count' do
        get checkout_booking_path(booking)
      end
    end

    assert_redirected_to 'https://sandbox.mercadopago.cl/checkout'
  end

  test 'webhook approved confirms booking' do
    sign_in @renter
    booking = create_pending_booking
    create_payment_for(booking)

    with_mercadopago_payment_stub(booking, status: 'approved') do
      post payments_webhooks_mercadopago_path, params: webhook_payload(booking, status: 'approved')
    end
    assert_response :success

    booking.reload
    assert booking.confirmed?
    assert booking.payment.approved?
  end

  test 'expire job frees slot for new booking' do
    sign_in @renter
    booking = create_pending_booking
    booking.update!(payment_expires_at: 1.minute.ago)

    Bookings::ExpirePendingJob.perform_now

    assert_difference 'Booking.count', 1 do
      post box_bookings_path(@box), params: booking_params
    end
  end

  test 'renter can cancel pending booking' do
    sign_in @renter
    booking = create_pending_booking

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      patch cancel_booking_path(booking)
    end

    assert_redirected_to bookings_path
    assert booking.reload.cancelled?
  end

  test 'webhook rejected keeps booking pending' do
    sign_in @renter
    booking = create_pending_booking
    create_payment_for(booking)

    with_mercadopago_payment_stub(booking, status: 'rejected') do
      post payments_webhooks_mercadopago_path, params: webhook_payload(booking, status: 'rejected')
    end
    assert_response :success

    booking.reload
    assert booking.pending_payment?
    assert booking.payment.rejected?
  end

  test 'renter sees bookings index' do
    sign_in @renter
    booking = create_pending_booking

    get bookings_path
    assert_response :success
    assert_match booking.box.title, response.body
  end

  test 'owner can view booking on their box' do
    sign_in @owner
    booking = create_pending_booking

    get booking_path(booking)
    assert_response :success
    assert_match booking.box.title, response.body
  end

  test 'checkout without mercado pago token shows alert' do
    sign_in @renter
    booking = create_pending_booking

    with_mercadopago_stub do
      without_env('MERCADOPAGO_ACCESS_TOKEN') do
        get checkout_booking_path(booking)
        assert_redirected_to booking_path(booking)
        assert_match 'Mercado Pago no configurado', flash[:alert]
      end
    end
  end

  test 'rejects overlapping slot' do
    sign_in @renter
    create_pending_booking

    assert_no_difference 'Booking.count' do
      post box_bookings_path(@box), params: booking_params
    end

    assert_response :unprocessable_entity
    assert_match 'ya no está disponible', response.body
  end

  test 'rejects hours below minimum' do
    sign_in @renter

    assert_no_difference 'Booking.count' do
      post box_bookings_path(@box), params: booking_params(hours: 1)
    end

    assert_response :unprocessable_entity
    assert_match 'mínimo 2 hora', response.body
  end

  test 'rejects booking outside availability rules' do
    sign_in @renter
    late_time = next_monday_at(hour: 19)

    assert_no_difference 'Booking.count' do
      post box_bookings_path(@box), params: booking_params(time: late_time, hours: 2)
    end

    assert_response :unprocessable_entity
    assert_match 'Fuera del horario ofrecido', response.body
  end

  test 'rejects booking during availability block' do
    sign_in @renter
    @box.availability_blocks.create!(
      start_at: @slot_time,
      end_at: @slot_time + 4.hours,
      reason: 'Mantenimiento'
    )

    assert_no_difference 'Booking.count' do
      post box_bookings_path(@box), params: booking_params
    end

    assert_response :unprocessable_entity
    assert_match 'Horario bloqueado', response.body
  end

  private

  def booking_params(time: @slot_time, hours: 2)
    {
      booking_type: 'single',
      date: booking_date_param(time),
      start_time: booking_start_time_param(time),
      hours: hours
    }
  end

  def create_pending_booking
    Booking.create!(
      box: @box,
      renter: @renter,
      start_at: @slot_time,
      end_at: @slot_time + 2.hours,
      hours: 2,
      total_amount_cents: @box.price_for_duration(2),
      status: :pending_payment,
      payment_expires_at: 30.minutes.from_now
    )
  end

  def create_payment_for(booking)
    Payment.create!(
      booking: booking,
      payer: @renter,
      mercadopago_preference_id: 'TEST-pref-existing',
      amount_cents: booking.total_amount_cents,
      status: :pending
    )
  end

  def webhook_payload(booking, status:)
    {
      'data' => { 'id' => "mp-pay-#{booking.id}", 'status' => status },
      'external_reference' => booking.id.to_s
    }
  end

  def with_mercadopago_payment_stub(booking, status:, &)
    fake_payment = Object.new
    fake_payment.define_singleton_method(:get) do |payment_id|
      {
        response: {
          'id' => payment_id,
          'status' => status,
          'external_reference' => booking.id.to_s
        }
      }
    end

    fake_sdk = Object.new
    fake_sdk.define_singleton_method(:payment) { fake_payment }

    Mercadopago::SDK.stub(:new, ->(_token) { fake_sdk }, &)
  end

  def without_env(key)
    original = ENV.fetch(key, nil)
    ENV.delete(key)
    yield
  ensure
    ENV[key] = original
  end
end
