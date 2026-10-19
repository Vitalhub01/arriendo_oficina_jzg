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
end
