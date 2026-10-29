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
               price_clp: 9000,
               name: 'Domingo'
             }
           },
           as: :json
    end

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
end
