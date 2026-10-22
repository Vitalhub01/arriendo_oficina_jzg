# frozen_string_literal: true

require 'test_helper'

class SiteFeatureSettingsTest < ActiveSupport::TestCase
  test 'memberships disabled by default' do
    SiteSetting.where(key: SiteFeatureSettings::MEMBERSHIPS_ENABLED_KEY).delete_all
    Rails.cache.delete(SiteFeatureSettings::CACHE_KEY)

    assert_not SiteFeatureSettings.memberships_enabled?
  end

  test 'set memberships enabled' do
    SiteFeatureSettings.set_memberships_enabled!(true)
    assert SiteFeatureSettings.memberships_enabled?

    SiteFeatureSettings.set_memberships_enabled!(false)
    assert_not SiteFeatureSettings.memberships_enabled?
  end
end
