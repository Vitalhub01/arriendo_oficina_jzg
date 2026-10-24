# frozen_string_literal: true

require 'test_helper'

class AdminSpaceCreateTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
  end

  test 'creating a space seeds default schedule blocks' do
    sign_in @admin

    assert_difference -> { Space.count }, 1 do
      post admin_spaces_path, params: {
        space: {
          title: 'Nuevo box prueba',
          description: 'Descripción',
          address: 'Av. Test 100',
          commune: 'Providencia',
          city: 'Santiago',
          box_type: 'clinical',
          capacity: 2,
          dimensions: '3x3',
          slot_duration_minutes: 60,
          minimum_slots: 1,
          minimum_hours: 1,
          status: 'draft'
        },
        pricing: admin_pricing_params
      }
    end

    space = Space.order(:id).last
    assert_redirected_to edit_admin_space_path(space)
    assert_equal 68, space.schedule_blocks.count
  end
end
