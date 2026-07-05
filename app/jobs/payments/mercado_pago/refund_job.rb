# frozen_string_literal: true

module Payments
  module MercadoPago
    class RefundJob < ApplicationJob
      queue_as :default

      def perform(payment_id)
        payment = Payment.find_by(id: payment_id)
        return unless payment&.approved? && payment.mercadopago_payment_id.present?
        return if access_token.blank?

        sdk = ::Mercadopago::SDK.new(access_token)
        sdk.refund.create(payment.mercadopago_payment_id)
        payment.update!(status: :refunded)
      rescue StandardError => e
        Rails.logger.error("[RefundJob] payment=#{payment_id} error=#{e.message}")
      end

      private

      def access_token
        ENV.fetch('MERCADOPAGO_ACCESS_TOKEN', nil)
      end
    end
  end
end
