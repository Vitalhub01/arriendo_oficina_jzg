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

    def edit
      @settings = SETTING_KEYS.index_with { |key| SiteSetting.get(key) }
    end

    def update
      settings_params.each do |key, value|
        SiteSetting.set(key, value)
      end

      redirect_to edit_admin_site_settings_path, notice: 'Configuración actualizada'
    end

    private

    def settings_params
      params.expect(site_settings: SETTING_KEYS)
    end
  end
end
