# frozen_string_literal: true

module Payments
  module MercadoPago
    module SiteUrl
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
        ENV.fetch('APP_HOST', 'localhost:3000').sub(%r{\Ahttps?://}i, '').delete_suffix('/')
      end

      def protocol
        return 'https' if Rails.env.production?
        return 'https' if ENV['MERCADOPAGO_HTTPS_BACK_URLS'] == 'true'
        return 'https' if host.exclude?('localhost') && host.exclude?('127.0.0.1')

        'http'
      end

      def url_helpers
        Rails.application.routes.url_helpers
      end
    end
  end
end
