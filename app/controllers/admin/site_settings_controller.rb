# frozen_string_literal: true

module Admin
  class SiteSettingsController < Admin::BaseController
    SETTING_KEYS = %w[
      reschedule_notice_hours
      google_analytics_id
      contact_email
      contact_phone
      hero_title
      hero_subtitle
    ].freeze

    NAV_SETTING_KEYS = SiteNavigationSettings::KEYS

    def edit
      @settings = SETTING_KEYS.index_with { |key| SiteSetting.get(key) }
      @nav_settings = NAV_SETTING_KEYS.index_with { |key| SiteNavigationSettings.value(key) }
      @memberships_enabled = SiteFeatureSettings.memberships_enabled?
    end

    def update
      settings_params.each do |key, value|
        SiteSetting.set(key, value)
      end

      nav_settings_params.each do |key, value|
        SiteSetting.set(key, value)
      end

      if params.key?(:site_feature_settings)
        raw = params.dig(:site_feature_settings, :memberships_enabled)
        enabled = Array.wrap(raw).include?('1')
        SiteFeatureSettings.set_memberships_enabled!(enabled)
      end

      redirect_to edit_admin_site_settings_path, notice: 'Configuración actualizada'
    end

    private

    def settings_params
      params.expect(site_settings: SETTING_KEYS)
    end

    def nav_settings_params
      params.expect(site_nav_settings: NAV_SETTING_KEYS)
    end
  end
end
