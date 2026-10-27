# frozen_string_literal: true

require 'test_helper'

class SpaceCheckoutTest < ActionDispatch::IntegrationTest
  setup do
    @space = boxes(:published_box)
    @slot_time = next_monday_at(hour: 10)
  end

  test 'guest checkout prompts sign in to confirm' do
    get checkout_space_path(@space)
    assert_response :success
    assert_match 'Inicia sesión o regístrate para confirmar y pagar', response.body
    assert_match 'Iniciar sesión o registrarse', response.body
  end

  test 'guest checkout defaults to first bookable date' do
    travel_to Time.zone.local(2026, 6, 14, 10, 0, 0) do
      get checkout_space_path(@space)
      assert_response :success
      assert_match @space.first_bookable_date.iso8601, response.body
    end
  end

  test 'guest checkout bloque mode shows both block prices' do
    travel_to Time.zone.local(2026, 6, 15, 10, 0, 0) do
      date = @space.first_bookable_date
      morning = @space.bloque_slot_rates.find_by!(name: 'Mañana')
      afternoon = @space.bloque_slot_rates.find_by!(name: 'Tarde')

      get checkout_space_path(
        @space,
        date: date,
        reservation_mode: 'bloque',
        slot_rate_id: morning.id
      )

      assert_response :success
      assert_match Money.new(morning.block_price_cents_effective, 'CLP').format(no_cents_if_whole: true), response.body
      assert_match Money.new(afternoon.block_price_cents_effective, 'CLP').format(no_cents_if_whole: true), response.body
    end
  end

  test 'guest can open checkout with slot params' do
    get checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )

    assert_response :success
    assert_match 'Confirmar reserva', response.body
    assert_match 'Iniciar sesión', response.body
    assert_match 'Registrarse', response.body
    assert_match @space.title, response.body
  end

  test 'guest slot link on space show points to checkout' do
    get space_path(@space)
    assert_response :success
    assert_match 'checkout', response.body
    assert_match 'reservation_mode=hora', response.body
  end

  test 'turbo frame refresh returns checkout frame' do
    get checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    ), headers: { 'Turbo-Frame' => 'space_checkout' }

    assert_response :success
    assert_match 'id="space_checkout"', response.body
    assert_no_match 'Confirmar reserva</h1>', response.body
  end

  test 'signed in user sees confirm and pay on checkout' do
    sign_in users(:renter)

    get checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )

    assert_response :success
    assert_match 'Confirmar y pagar', response.body
    assert_no_match 'Iniciar sesión', response.body
  end

  test 'checkout shows equipment rental option and total when enabled' do
    item = equipment_items(:wifi_equipment)
    item.update_columns(price_per_hour_cents: 500)

    get checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2,
      rented_equipment_item_ids: [item.id]
    )

    assert_response :success
    assert_match "Agregar #{item.name}", response.body
    assert_match '$31.000', response.body
  end

  test 'checkout total increases when equipment checkbox is selected' do
    item = equipment_items(:wifi_equipment)
    item.update_columns(price_per_hour_cents: 500)
    base_params = {
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    }

    get checkout_space_path(@space, **base_params)
    assert_response :success
    assert_match '$30.000', response.body
    assert_no_match '$31.000', response.body

    get checkout_space_path(@space, **base_params, rented_equipment_item_ids: [item.id])
    assert_response :success
    assert_match '$31.000', response.body
  end

  test 'turbo frame refresh with multiple hours updates checkout' do
    get checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    ), headers: { 'Turbo-Frame' => 'space_checkout' }

    assert_response :success
    assert_match '2 hora(s)', response.body
    assert_match '$30.000', response.body
  end

  test 'checkout stores return path for sign in' do
    checkout_url = checkout_space_path(
      @space,
      date: @slot_time.to_date,
      start_time: '10:00',
      reservation_mode: 'hora',
      slot_count: 2
    )
    get checkout_url
    assert_response :success

    sign_in users(:renter)
    follow_redirect! if response.redirect?
    get checkout_url
    assert_response :success
  end
end
