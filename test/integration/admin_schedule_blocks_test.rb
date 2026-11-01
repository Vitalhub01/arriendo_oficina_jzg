# frozen_string_literal: true

require 'test_helper'

class AdminScheduleBlocksTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @space = boxes(:published_box)
  end

  test 'schedule blocks index loads' do
    sign_in @admin
    get admin_space_schedule_blocks_path(@space)
    assert_response :success
    assert_match 'Calendario y precios', response.body
    assert_match 'Rellenar por rango', response.body
  end

  test 'bulk fill creates blocks' do
    sign_in @admin
    @space.schedule_blocks.destroy_all

    post bulk_fill_admin_space_schedule_blocks_path(@space), params: {
      days: [0, 1],
      start_time: '10:00',
      end_time: '12:00',
      price_clp: 8000,
      replace_overlapping: '1'
    }

    assert_response :redirect
    assert_match %r{/admin/spaces/#{@space.id}/schedule_blocks}, response.location
    assert_equal 4, @space.schedule_blocks.count
  end

  test 'bulk fill without price uses space morning and afternoon rates' do
    sign_in @admin
    @space.schedule_blocks.destroy_all

    post bulk_fill_admin_space_schedule_blocks_path(@space), params: {
      days: [0],
      start_time: '10:00',
      end_time: '16:00',
      replace_overlapping: '1'
    }

    assert_response :redirect
    morning = @space.schedule_blocks.for_day(0).find_by(start_time: Time.zone.parse('2000-01-01 10:00:00'))
    afternoon = @space.schedule_blocks.for_day(0).find_by(start_time: Time.zone.parse('2000-01-01 14:00:00'))
    assert_equal @space.morning_hourly_price_cents, morning.price_cents
    assert_equal @space.afternoon_hourly_price_cents, afternoon.price_cents
  end

  test 'bulk fill replace keeps blocks with active bookings' do
    sign_in @admin
    start_at = next_monday_at(hour: 9)
    booking = create_confirmed_booking!(@space, start_at)
    block = overlapping_template_block(booking)

    post bulk_fill_admin_space_schedule_blocks_path(@space), params: {
      days: [block.day_of_week],
      start_time: '08:00',
      end_time: '12:00',
      replace_overlapping: '1'
    }

    assert_response :redirect
    assert @space.schedule_blocks.exists?(block.id), 'expected booked template block to remain'
  end

  test 'destroy schedule block blocked when booking exists' do
    sign_in @admin
    start_at = next_monday_at(hour: 9)
    booking = create_confirmed_booking!(@space, start_at)
    block = overlapping_template_block(booking)

    assert_no_difference -> { @space.schedule_blocks.count } do
      delete admin_space_schedule_block_path(@space, block), as: :json
    end

    assert_response :unprocessable_content
    json = JSON.parse(response.body)
    assert_match(/reservas activas/i, json['errors'].join(' '))
  end

  test 'admin updates schedule block template via json' do
    sign_in @admin
    block = schedule_blocks(:published_d0_h9)

    patch admin_space_schedule_block_path(@space, block),
          params: {
            schedule_block: {
              day_of_week: block.day_of_week,
              start_time: block.start_time.strftime('%H:%M'),
              end_time: block.end_time.strftime('%H:%M'),
              price_clp: 12_500,
              name: 'Mañana temprano'
            }
          },
          as: :json

    assert_response :success
    block.reload
    assert_equal 12_500, block.price_cents
    assert_equal 'Mañana temprano', block.name
  end

  test 'admin creates schedule block template via json' do
    sign_in @admin
    @space.schedule_blocks.for_day(6).destroy_all

    assert_difference -> { @space.schedule_blocks.count }, 1 do
      post admin_space_schedule_blocks_path(@space),
           params: {
             schedule_block: {
               day_of_week: 6,
               start_time: '10:00',
               end_time: '11:00',
               name: 'Domingo'
             }
           },
           as: :json
    end

    assert_response :created
    block = @space.schedule_blocks.for_day(6).order(:created_at).last
    assert_equal @space.price_per_slot_at(Time.zone.parse('2000-01-01 10:00:00')), block.price_cents
  end

  test 'admin creates schedule block with explicit special price' do
    sign_in @admin
    @space.schedule_blocks.for_day(6).destroy_all

    post admin_space_schedule_blocks_path(@space),
         params: {
           schedule_block: {
             day_of_week: 6,
             start_time: '10:00',
             end_time: '11:00',
             price_clp: 9000,
             name: 'Domingo promo'
           }
         },
         as: :json

    assert_response :created
    block = @space.schedule_blocks.for_day(6).order(:created_at).last
    assert_equal 9000, block.price_cents
  end

  test 'admin updates volume discount from schedule page form' do
    sign_in @admin
    rule = @space.pricing_rules.create!(
      name: 'Descuento volumen test',
      rule_type: :volume_discount,
      config: { 'min_slots' => 4, 'discount_percent' => 10 },
      active: true,
      priority: 10
    )

    patch admin_space_volume_pricing_rule_path(@space, rule), params: {
      pricing_rule: {
        name: rule.name,
        active: '1',
        config: { min_slots: 6, discount_percent: 15 }
      }
    }

    assert_redirected_to admin_space_schedule_blocks_path(@space)
    rule.reload
    assert_equal 6, rule.config['min_slots'].to_i
    assert_equal 15, rule.config['discount_percent'].to_i
  end

  private

  def create_confirmed_booking!(space, start_at)
    result = Bookings::Create.new(
      space: space,
      profesional: users(:renter),
      params: {
        date: start_at.to_date.to_s,
        start_time: start_at.strftime('%H:%M'),
        slot_count: 2
      }
    ).call
    raise result.errors.inspect unless result.success?

    booking = result.booking
    booking.update!(status: :confirmed, payment_expires_at: nil)
    booking
  end

  def overlapping_template_block(booking)
    day = (booking.start_at.wday + 6) % 7
    booking.space.schedule_blocks.for_day(day).find do |block|
      ScheduleBlocks::BookingGuard.overlaps?(booking, block)
    end
  end
end
