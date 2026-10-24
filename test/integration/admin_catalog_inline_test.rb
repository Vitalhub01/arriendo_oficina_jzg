# frozen_string_literal: true

require 'test_helper'

class AdminCatalogInlineTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @space = boxes(:published_box)
    sign_in @admin
  end

  test 'inline equipment create assigns to space and returns turbo stream' do
    assert_difference 'EquipmentItem.count', 1 do
      post admin_equipment_items_path,
           params: {
             inline: '1',
             from_space_id: @space.id,
             equipment_item: { name: 'Nuevo sillón', price_per_hour_cents: 2000 }
           },
           as: :turbo_stream
    end

    item = EquipmentItem.order(:id).last
    assert_includes @space.reload.equipment_item_ids, item.id
    assert_response :success
    assert_match 'space_equipment_items_list', response.body
    assert_match 'Nuevo sillón', response.body
  end

  test 'inline amenity tag create assigns to space' do
    assert_difference 'AmenityTag.count', 1 do
      post admin_amenity_tags_path,
           params: {
             inline: '1',
             from_space_id: @space.id,
             amenity_tag: { name: 'Estacionamiento' }
           },
           as: :turbo_stream
    end

    tag = AmenityTag.order(:id).last
    assert_includes @space.reload.amenity_tag_ids, tag.id
    assert_response :success
    assert_match 'Estacionamiento', response.body
  end
end
