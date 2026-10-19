# frozen_string_literal: true

module Payments
  module MercadoPago
    # Sync payment when the user returns from Checkout Pro (query params on back_urls).
    class ProcessReturn
      def initialize(booking:, params:)
        @booking = booking
        @params = params
      end

      def call
        return false unless mercadopago_return?

        payment_id = @params[:payment_id].presence || @params['payment_id'].presence
        return false unless payment_id

        ProcessWebhook.new(
          'data' => { 'id' => payment_id.to_s },
          'type' => 'payment'
        ).call
      end

      private

      def mercadopago_return?
        @params[:collection_status].present? ||
          @params[:payment_id].present? ||
          @params[:status].present? ||
          @params[:preference_id].present?
      end
    end
  end
end
