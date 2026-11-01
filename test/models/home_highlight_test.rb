# frozen_string_literal: true

require 'test_helper'

class HomeHighlightTest < ActiveSupport::TestCase
  test 'rendered_description replaces city placeholder' do
    highlight = HomeHighlight.new(description: 'En {ciudad} centro')

    assert_equal 'En Valparaíso centro', highlight.rendered_description(office_city: 'Valparaíso')
  end

  test 'rendered_description uses default city when blank' do
    highlight = HomeHighlight.new(description: '{ciudad}')

    assert_equal 'Chile', highlight.rendered_description(office_city: nil)
  end

  test 'normalizes invalid icon key to default' do
    highlight = HomeHighlight.new(title: 'Test', description: 'Desc', icon_key: 'not_an_icon')

    assert highlight.valid?
    assert_equal HomeHighlightIcons::DEFAULT_KEY, highlight.icon_key
  end
end
