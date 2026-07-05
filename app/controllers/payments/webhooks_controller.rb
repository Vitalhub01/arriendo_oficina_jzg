# frozen_string_literal: true

module Payments
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user!, raise: false

    def mercadopago
      payload = webhook_params
      unless Payments::MercadoPago::VerifyWebhook.new(request_headers: request.headers, payload: payload).valid?
        head :unauthorized
        return
      end

      Payments::MercadoPago::ProcessWebhook.new(payload).call
      head :ok
    end

    private

    def webhook_params
      if request.content_type&.include?('application/json')
        JSON.parse(request.raw_post)
      else
        params.permit(
          :action, :type, :id, :live_mode, :external_reference, :status,
          data: %i[id status]
        ).to_h
      end
    rescue JSON::ParserError
      {}
    end
  end
end
