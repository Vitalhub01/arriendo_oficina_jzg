# frozen_string_literal: true

module Payments
  module MercadoPago
    class VerifyWebhook
      def initialize(request_headers:, payload:)
        @request_headers = request_headers
        @payload = payload
      end

      def valid?
        secret = ENV.fetch('MERCADOPAGO_WEBHOOK_SECRET', nil)
        return true if secret.blank?

        signature_header = @request_headers['x-signature'] || @request_headers['X-Signature']
        request_id = @request_headers['x-request-id'] || @request_headers['X-Request-Id']
        return false if signature_header.blank? || request_id.blank?

        parts = signature_header.split(',').to_h { |part| part.strip.split('=', 2) }
        ts = parts['ts']
        v1 = parts['v1']
        return false if ts.blank? || v1.blank?

        data_id = extract_data_id
        return false if data_id.blank?

        manifest = "id:#{data_id};request-id:#{request_id};ts:#{ts};"
        expected = OpenSSL::HMAC.hexdigest('SHA256', secret, manifest)
        ActiveSupport::SecurityUtils.secure_compare(expected, v1)
      end

      private

      def extract_data_id
        parsed = @payload.is_a?(Hash) ? @payload : {}
        parsed.dig('data', 'id') || parsed['id']
      end
    end
  end
end
