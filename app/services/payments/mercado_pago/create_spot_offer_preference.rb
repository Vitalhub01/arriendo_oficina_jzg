# frozen_string_literal: true

module Payments
  module MercadoPago
    class CreateSpotOfferPreference
      def initialize(spot_offer:, payer:)
        @spot_offer = spot_offer
        @payer = payer
      end

      def call
        return failure('Mercado Pago no configurado') if access_token.blank?
        if SiteUrl.production_localhost?(success_url)
          return failure('APP_HOST o APP_BASE_URL debe apuntar al dominio público en producción')
        end

        sdk = ::Mercadopago::SDK.new(access_token)
        preference_data = {
          items: [{
            title: "Tarifa spot: #{@spot_offer.space.title}",
            quantity: 1,
            unit_price: @spot_offer.total_price_cents,
            currency_id: 'CLP'
          }],
          payer: { email: @payer.email },
          back_urls: {
            success: success_url,
            failure: failure_url,
            pending: pending_url
          },
          external_reference: "spot-#{@spot_offer.id}",
          notification_url: webhook_url
        }.merge(PreferenceOptions.auto_return_for(success_url))

        response = sdk.preference.create(preference_data)
        preference = response[:response]

        if response[:status] == 201 && preference && preference['id']
          payment = @spot_offer.payment || Payment.new(spot_offer: @spot_offer, payer: @payer, payment_kind: :spot_offer)
          payment.assign_attributes(
            mercadopago_preference_id: preference['id'],
            amount_cents: @spot_offer.total_price_cents,
            status: :pending
          )
          payment.save!
          Result.new(success: true, payment: payment, init_point: CheckoutUrl.from_preference(preference))
        else
          failure(PreferenceOptions.error_from_response(response) || 'Error al crear preferencia de pago')
        end
      rescue StandardError => e
        failure(e.message)
      end

      private

      def access_token
        ENV.fetch('MERCADOPAGO_ACCESS_TOKEN', nil)
      end

      def success_url
        SiteUrl.path(Rails.application.routes.url_helpers.spot_offer_path(@spot_offer.token))
      end

      def failure_url
        success_url
      end

      def pending_url
        success_url
      end

      def webhook_url
        SiteUrl.path(Rails.application.routes.url_helpers.payments_webhooks_mercadopago_path)
      end

      def failure(message)
        Result.new(success: false, error: message)
      end

      class Result
        attr_reader :payment, :init_point, :error

        def initialize(success:, payment: nil, init_point: nil, error: nil)
          @success = success
          @payment = payment
          @init_point = init_point
          @error = error
        end

        def success?
          @success
        end
      end
    end
  end
end
