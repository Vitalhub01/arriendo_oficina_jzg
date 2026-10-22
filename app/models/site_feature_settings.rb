# frozen_string_literal: true

class SiteFeatureSettings
  CACHE_KEY = 'site_feature_settings/v1'
  MEMBERSHIPS_ENABLED_KEY = 'memberships_enabled'

  def self.memberships_enabled?
    load_all[MEMBERSHIPS_ENABLED_KEY]
  end

  def self.load_all
    Rails.cache.fetch(CACHE_KEY, expires_in: 1.hour) do
      raw = SiteSetting.get(MEMBERSHIPS_ENABLED_KEY, 'false')
      { MEMBERSHIPS_ENABLED_KEY => ActiveModel::Type::Boolean.new.cast(raw) }
    end
  end

  def self.set_memberships_enabled!(enabled)
    SiteSetting.set(MEMBERSHIPS_ENABLED_KEY, enabled ? 'true' : 'false')
    Rails.cache.delete(CACHE_KEY)
  end
end
