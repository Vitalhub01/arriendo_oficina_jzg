# frozen_string_literal: true

require 'test_helper'

class AdminFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @renter = users(:renter)
    @published = boxes(:published_box)
    @profile = professional_profiles(:renter_profile)
  end

  test 'admin dashboard shows metrics' do
    sign_in @admin
    get admin_root_path
    assert_response :success
    assert_match 'Espacios', response.body
    assert_match 'Reservas', response.body
  end

  test 'admin can edit office' do
    sign_in @admin
    get edit_admin_office_path
    assert_response :success

    patch admin_office_path, params: {
      office: { name: 'Oficina JZG Test', address: 'Calle 1', commune: 'Providencia', city: 'Santiago' }
    }
    assert_redirected_to edit_admin_office_path
    assert_equal 'Oficina JZG Test', Office.first.name
  end

  test 'admin suspends space and it disappears from public catalog' do
    sign_in @admin

    patch admin_space_path(@published), params: { space: { status: 'suspended' } }
    assert_redirected_to admin_space_path(@published)
    assert @published.reload.suspended?

    get spaces_path
    assert_no_match @published.title, response.body
  end

  test 'admin creates slot rate for space' do
    sign_in @admin

    assert_difference -> { @published.slot_rates.count }, 1 do
      post admin_space_slot_rates_path(@published), params: {
        slot_rate: {
          name: 'Mañana',
          start_time: '09:00',
          end_time: '12:00',
          price_per_slot_cents: 12_000,
          position: 1
        }
      }
    end

    assert_redirected_to admin_space_slot_rates_path(@published)
  end

  test 'admin adds and removes availability rule' do
    sign_in @admin
    space = boxes(:draft_box)

    assert_difference -> { space.availability_rules.count }, 1 do
      post admin_space_availability_rules_path(space), params: {
        availability_rule: {
          day_of_week: 6,
          start_time: '10:00',
          end_time: '14:00'
        }
      }
    end

    rule = space.availability_rules.order(:created_at).last
    assert_difference -> { space.availability_rules.count }, -1 do
      delete admin_space_availability_rule_path(space, rule)
    end
    assert_redirected_to admin_space_availability_rules_path(space)
  end

  test 'admin availability block prevents public booking' do
    sign_in @admin
    slot_time = next_monday_at(hour: 10)

    post admin_space_availability_blocks_path(@published), params: {
      availability_block: {
        start_at: slot_time,
        end_at: slot_time + 3.hours,
        reason: 'Mantenimiento'
      }
    }
    assert_redirected_to admin_space_availability_blocks_path(@published)

    sign_in @renter
    post space_bookings_path(@published), params: {
      date: booking_date_param(slot_time),
      start_time: booking_start_time_param(slot_time),
      slot_count: 2
    }

    assert_response :unprocessable_entity
    assert_match 'Horario bloqueado', response.body
  end

  test 'admin approves pending professional' do
    sign_in @admin
    profile = professional_profiles(:profesional_profile)
    profile.update_columns(validation_status: ProfessionalProfile.validation_statuses[:pending])

    patch admin_professional_path(profile), params: { approve: '1' }
    assert_redirected_to admin_professional_path(profile)
    assert profile.reload.manual_verified?
  end

  test 'admin bans and unbans professional' do
    sign_in @admin
    user = @renter

    patch admin_professional_path(@profile), params: { ban: true }
    assert_redirected_to admin_professional_path(@profile)
    assert user.reload.banned?

    patch admin_professional_path(@profile), params: { unban: true }
    assert_redirected_to admin_professional_path(@profile)
    assert_not user.reload.banned?
  end

  test 'admin uploads space photo' do
    sign_in @admin
    space = boxes(:draft_box)
    file = fixture_file_upload('cover.jpg', 'image/jpeg')

    patch admin_space_path(space), params: {
      space: {
        title: space.title,
        address: space.address,
        commune: space.commune,
        city: space.city,
        price_per_hour_cents: space.price_per_hour_cents,
        photos: [file]
      }
    }

    assert_redirected_to admin_space_path(space)
    assert space.reload.photos.attached?
  end

  test 'non-admin cannot access admin panel' do
    sign_in @renter
    get admin_root_path
    assert_redirected_to root_path
    assert_match 'Acceso no autorizado', flash[:alert]
  end
end
