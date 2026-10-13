# frozen_string_literal: true

module Payments
  module MercadoPago
    module PreferenceOptions
      module_function

      # Mercado Pago rejects auto_return when back_urls are not HTTPS (e.g. local http://localhost).
      def auto_return_for(success_url)
        success_url.to_s.start_with?('https://') ? { auto_return: 'approved' } : {}
      end

      def error_from_response(response)
        body = response[:response]
        return unless body.is_a?(Hash)

        [body['message'], body['error']].compact.join(' — ').presence
      end
    end
  end
end
