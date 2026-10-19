# frozen_string_literal: true

require 'test_helper'

class AdminSpaceUpdateTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @space = boxes(:published_box)
    attach_box_photo(@space) unless @space.photos_attached?
  end

  test 'admin updates pricing from edit form fields' do
    sign_in @admin

    patch admin_space_path(@space), params: {
      space: {
        title: @space.title,
        description: @space.description,
        office_id: @space.office_id,
        slot_duration_minutes: @space.slot_duration_minutes,
        minimum_slots: @space.minimum_slots,
        capacity: @space.capacity,
        dimensions: @space.dimensions,
        status: @space.status
      },
      pricing: admin_pricing_params(morning_hourly_price_cents: 18_000)
    }

    assert_redirected_to edit_admin_space_path(@space)
    @space.reload
    assert_equal 18_000, @space.price_per_hour_cents
    assert_equal 18_000, @space.slot_rates.find_by(name: 'Mañana').price_per_slot_cents
    assert_equal 55_000, @space.primary_jornada_definition.price_cents
  end
end
