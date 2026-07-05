# frozen_string_literal: true

require 'test_helper'

module Payments
  module MercadoPago
    class VerifyWebhookTest < ActiveSupport::TestCase
      test 'allows webhook when secret is not configured' do
        verify = Payments::MercadoPago::VerifyWebhook.new(
          request_headers: {},
          payload: { 'data' => { 'id' => '123' } }
        )
        assert verify.valid?
      end

      test 'rejects invalid signature when secret configured' do
        ENV['MERCADOPAGO_WEBHOOK_SECRET'] = 'test-secret'
        verify = Payments::MercadoPago::VerifyWebhook.new(
          request_headers: { 'x-signature' => 'ts=1,v1=bad', 'x-request-id' => 'req-1' },
          payload: { 'data' => { 'id' => '123' } }
        )
        assert_not verify.valid?
      ensure
        ENV.delete('MERCADOPAGO_WEBHOOK_SECRET')
      end
    end
  end
end
