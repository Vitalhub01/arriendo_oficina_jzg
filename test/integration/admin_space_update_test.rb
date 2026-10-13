# frozen_string_literal: true

require 'test_helper'

class AdminSpaceUpdateTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @space = boxes(:published_box)
    attach_box_photo(@space) unless @space.photos.attached?
  end

  test 'admin updates price from edit form fields' do
    sign_in @admin

    patch admin_space_path(@space), params: {
      space: {
        title: @space.title,
        description: @space.description,
        office_id: @space.office_id,
        price_per_hour_cents: 18_000,
        slot_duration_minutes: @space.slot_duration_minutes,
        minimum_slots: @space.minimum_slots,
        capacity: @space.capacity,
        dimensions: @space.dimensions,
        status: @space.status
      }
    }

    assert_redirected_to edit_admin_space_path(@space)
    assert_equal 18_000, @space.reload.price_per_hour_cents
  end
end
