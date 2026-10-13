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
  end
end
