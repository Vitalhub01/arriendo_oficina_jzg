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
      @branding = SiteBranding.current
    end

    def update
      settings_params.each do |key, value|
        SiteSetting.set(key, value)
      end

      nav_settings_params.each do |key, value|
        SiteSetting.set(key, value)
      end

      @branding = SiteBranding.current
      if @branding.update(site_branding_params)
        redirect_to edit_admin_site_settings_path, notice: 'Configuración actualizada'
      else
        @settings = SETTING_KEYS.index_with { |key| SiteSetting.get(key) }
        @nav_settings = NAV_SETTING_KEYS.index_with { |key| SiteNavigationSettings.value(key) }
        render :edit, status: :unprocessable_content
      end
    end

    private

    def settings_params
      params.expect(site_settings: SETTING_KEYS)
    end

    def nav_settings_params
      params.expect(site_nav_settings: NAV_SETTING_KEYS)
    end

    def site_branding_params
      params.fetch(:site_branding, {}).permit(:logo, :hero_image)
    end
  end
end
