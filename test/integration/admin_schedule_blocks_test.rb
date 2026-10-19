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
end
