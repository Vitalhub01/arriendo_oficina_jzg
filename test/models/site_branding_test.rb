# frozen_string_literal: true

require 'test_helper'

class SiteBrandingTest < ActiveSupport::TestCase
  test 'current returns a persisted record' do
    assert SiteBranding.current.persisted?
    assert_equal SiteBranding.current, SiteBranding.current
  end

  test 'rejects invalid logo content type' do
    branding = SiteBranding.current
    branding.logo.attach(
      io: StringIO.new('not an image'),
      filename: 'logo.txt',
      content_type: 'text/plain'
    )

    assert_not branding.valid?
    assert_includes branding.errors[:logo], 'debe ser PNG, JPG o WebP'
  end
end
