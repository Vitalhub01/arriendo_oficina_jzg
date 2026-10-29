# frozen_string_literal: true

require 'test_helper'

class AdminSaveFlowsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @space = boxes(:published_box)
  end

  test 'site settings guardar persists navigation text' do
    sign_in @admin
    new_label = 'Espacios JZG Test'
    nav_settings = SiteNavigationSettings::KEYS.index_with { |key| SiteNavigationSettings.value(key) }
    nav_settings['nav_link_spaces'] = new_label
    site_settings = Admin::SiteSettingsController::SETTING_KEYS.index_with { |key| SiteSetting.get(key) }

    patch admin_site_settings_path, params: {
      site_nav_settings: nav_settings,
      site_settings: site_settings
    }

    assert_redirected_to edit_admin_site_settings_path
    follow_redirect!
    assert_response :success
    assert_equal new_label, SiteNavigationSettings.value('nav_link_spaces')
  end

  test 'space edit guardar persists title and pricing' do
    sign_in @admin
    attach_box_photo(@space) unless @space.photos_attached?
    new_title = 'Sala actualizada por test'

    patch admin_space_path(@space), params: {
      space: {
        title: new_title,
        description: @space.description,
        office_id: @space.office_id,
        slot_duration_minutes: @space.slot_duration_minutes,
        minimum_slots: @space.minimum_slots,
        capacity: @space.capacity,
        dimensions: @space.dimensions,
        status: @space.status
      },
      pricing: admin_pricing_params(morning_hourly_price_cents: 19_000)
    }

    assert_redirected_to edit_admin_space_path(@space)
    @space.reload
    assert_equal new_title, @space.title
    assert_equal 19_000, @space.price_per_hour_cents
  end

  test 'schedule template save changes booking quote subtotal' do
    sign_in @admin
    block = schedule_blocks(:published_d0_h9)
    slot_time = next_monday_at(hour: block.start_time.hour)
    new_price = 22_000

    patch admin_space_schedule_block_path(@space, block),
          params: {
            schedule_block: {
              day_of_week: block.day_of_week,
              start_time: block.start_time.strftime('%H:%M'),
              end_time: block.end_time.strftime('%H:%M'),
              price_clp: new_price,
              name: block.name
            }
          },
          as: :json

    assert_response :success
    assert_equal new_price, block.reload.price_cents

    quote = Bookings::Quote.new(
      space: @space,
      user: users(:renter),
      params: {
        date: slot_time.to_date.iso8601,
        start_time: block.start_time.strftime('%H:%M'),
        reservation_mode: 'hora',
        slot_count: 1
      }
    ).call

    assert quote.success?
    assert_equal new_price, quote.pricing[:subtotal_cents]
  end
end
