# frozen_string_literal: true

require 'test_helper'

class AdminHomeHighlightsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @highlight = HomeHighlight.create!(
      title: 'Prueba ícono',
      description: 'Descripción',
      position: 99,
      visible: true,
      icon_key: 'clock'
    )
  end

  test 'admin can update highlight icon from edit form' do
    sign_in @admin

    patch admin_home_highlight_path(@highlight), params: {
      home_highlight: {
        title: @highlight.title,
        description: @highlight.description,
        position: @highlight.position,
        visible: '1',
        icon_key: 'sun'
      }
    }

    assert_redirected_to admin_home_highlights_path
    assert_equal 'sun', @highlight.reload.icon_key
  end
end
