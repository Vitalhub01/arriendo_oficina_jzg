# frozen_string_literal: true

module Payments
  module MercadoPago
    module SiteUrl
      PRODUCTION_DEFAULT_HOST = 'www.vitalhub.cl'
      LOCAL_DEV_HOST = 'localhost:3000'

      module_function

      def booking(booking)
        url_helpers.booking_url(booking, **url_options)
      end

      def path(relative_path)
        base = base_url
        suffix = relative_path.start_with?('/') ? relative_path : "/#{relative_path}"
        "#{base}#{suffix}"
      end

      def base_url
        explicit = ENV['APP_BASE_URL'].presence
        return explicit.delete_suffix('/') if explicit

        "#{protocol}://#{host}"
      end

      def url_options
        { host: host, protocol: protocol }
      end

      def host
        candidate = normalize_host(ENV['APP_HOST'].presence) ||
          normalize_host(routes_default_options[:host]) ||
          fallback_host
        resolve_production_host(candidate)
      end

      def protocol
        routes_protocol = routes_default_options[:protocol]
        return routes_protocol.to_s if routes_protocol.present?

        return 'https' if Rails.env.production?
        return 'https' if ENV['MERCADOPAGO_HTTPS_BACK_URLS'] == 'true'
        return 'https' if host.exclude?('localhost') && host.exclude?('127.0.0.1')

        'http'
      end

      def production_localhost?(url = base_url)
        return false unless Rails.env.production?

        url.to_s.match?(%r{\Ahttps?://(localhost|127\.0\.0\.1)(:\d+)?}i)
      end

      def normalize_host(value)
        return if value.blank?

        value.to_s.sub(%r{\Ahttps?://}i, '').delete_suffix('/').presence
      end

      def fallback_host
        Rails.env.production? ? PRODUCTION_DEFAULT_HOST : LOCAL_DEV_HOST
      end

      def resolve_production_host(candidate)
        return candidate unless Rails.env.production?
        return candidate unless localhost_host?(candidate)

        Rails.logger.warn(
          "[MercadoPago::SiteUrl] Host #{candidate} no es válido en producción; usando #{fallback_host}"
        )
        normalize_host(routes_default_options[:host]) || fallback_host
      end

      def localhost_host?(value)
        value.to_s.match?(/\A(localhost|127\.0\.0\.1)(:\d+)?\z/i)
      end

      def routes_default_options
        Rails.application.routes.default_url_options || {}
      end

      def url_helpers
        Rails.application.routes.url_helpers
      end
    end
  end
end
