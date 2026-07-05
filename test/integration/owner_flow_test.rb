# frozen_string_literal: true

require 'test_helper'

class OwnerFlowTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:owner)
    @renter = users(:renter)
    @box = boxes(:draft_box)
  end

  test 'owner sees their boxes' do
    sign_in @owner
    get owner_boxes_path
    assert_response :success
    assert_match boxes(:published_box).title, response.body
    assert_match boxes(:draft_box).title, response.body
  end

  test 'owner creates box and is redirected to availability rules' do
    sign_in @owner

    with_geocoder_stub do
      assert_difference 'Box.count', 1 do
        post owner_boxes_path, params: { box: new_box_params }
      end
    end

    box = Box.order(:created_at).last
    assert box.draft?
    assert_redirected_to owner_box_availability_rules_path(box)
  end

  test 'owner adds availability rule' do
    sign_in @owner

    assert_difference '@box.availability_rules.count', 1 do
      post owner_box_availability_rules_path(@box), params: {
        availability_rule: {
          day_of_week: 5,
          start_time: '09:00',
          end_time: '13:00'
        }
      }
    end

    assert_redirected_to owner_box_availability_rules_path(@box)
    rule = @box.availability_rules.order(:created_at).last
    assert_equal 5, rule.day_of_week
  end

  test 'publish fails without photos' do
    sign_in @owner
    box = boxes(:draft_box)
    box.update!(latitude: -33.42, longitude: -70.61)

    patch publish_owner_box_path(box)
    assert_redirected_to owner_box_path(box)
    assert_match 'foto', flash[:alert].downcase
    assert box.reload.draft?
  end

  test 'publish succeeds with photo and coordinates' do
    sign_in @owner
    box = boxes(:draft_box)
    box.update!(latitude: -33.42, longitude: -70.61)
    attach_box_photo(box)

    patch publish_owner_box_path(box)
    assert_redirected_to owner_box_path(box)
    assert box.reload.published?
  end

  test 'availability block prevents booking' do
    sign_in @owner
    box = boxes(:published_box)
    slot_time = next_monday_at(hour: 10)

    post owner_box_availability_blocks_path(box), params: {
      availability_block: {
        start_at: slot_time,
        end_at: slot_time + 3.hours,
        reason: 'Uso propio'
      }
    }
    assert_redirected_to owner_box_availability_blocks_path(box)

    sign_in @renter
    post box_bookings_path(box), params: {
      booking_type: 'single',
      date: booking_date_param(slot_time),
      start_time: booking_start_time_param(slot_time),
      hours: 2
    }

    assert_response :unprocessable_entity
    assert_match 'Horario bloqueado', response.body
  end

  test 'renter cannot access owner panel' do
    sign_in @renter
    get owner_boxes_path
    assert_redirected_to root_path
    assert_match 'Acceso no autorizado', flash[:alert]
  end

  test 'owner sees bookings on their boxes' do
    box = boxes(:published_box)
    slot_time = next_monday_at(hour: 10)
    booking = Booking.create!(
      box: box,
      renter: @renter,
      start_at: slot_time,
      end_at: slot_time + 2.hours,
      hours: 2,
      total_amount_cents: box.price_for_duration(2),
      status: :pending_payment
    )

    sign_in @owner
    get bookings_path

    assert_response :success
    assert_match box.title, response.body
    assert_match booking.formatted_total, response.body
  end

  private

  def new_box_params
    {
      title: 'Nuevo Box Test',
      description: 'Descripción de prueba',
      address: 'Av. Nueva 100',
      commune: 'Ñuñoa',
      city: 'Santiago',
      box_type: 'clinical',
      price_per_hour_cents: 12_000,
      minimum_hours: 1
    }
  end
end
