# frozen_string_literal: true

module Payments
  module MercadoPago
    class CreatePreference
      PREFERENCE_REUSE_WINDOW = 24.hours

      def initialize(booking:, payer:)
        @booking = booking
        @payer = payer
      end

      def call
        return failure('Mercado Pago no configurado') if access_token.blank?

        existing = reusable_pending_payment
        if existing
          return Result.new(
            success: true,
            payment: existing,
            init_point: existing_init_point(existing)
          )
        end

        sdk = ::Mercadopago::SDK.new(access_token)
        preference_data = {
          items: [{
            title: "Reserva: #{@booking.space.title}",
            quantity: 1,
            unit_price: @booking.total_amount_cents,
            currency_id: 'CLP'
          }],
          payer: { email: @payer.email },
          back_urls: {
            success: success_url,
            failure: failure_url,
            pending: pending_url
          },
          auto_return: 'approved',
          external_reference: @booking.id.to_s,
          notification_url: webhook_url
        }

        response = sdk.preference.create(preference_data)
        preference = response[:response]

        if preference && preference['id']
          payment = Payment.create!(
            booking: @booking,
            payer: @payer,
            payment_kind: :booking,
            mercadopago_preference_id: preference['id'],
            amount_cents: @booking.total_amount_cents,
            status: :pending
          )
          Result.new(success: true, payment: payment, init_point: preference['init_point'])
        else
          failure('Error al crear preferencia de pago')
        end
      rescue StandardError => e
        failure(e.message)
      end

      private

      def reusable_pending_payment
        payment = @booking.payment
        return unless payment&.pending?
        return unless payment.created_at >= PREFERENCE_REUSE_WINDOW.ago
        return if payment.mercadopago_preference_id.blank?

        payment
      end

      def existing_init_point(payment)
        sdk = ::Mercadopago::SDK.new(access_token)
        response = sdk.preference.get(payment.mercadopago_preference_id)
        response.dig(:response, 'init_point') || sandbox_init_point(response[:response])
      rescue StandardError
        nil
      end

      def sandbox_init_point(preference)
        preference&.dig('sandbox_init_point')
      end

      def access_token
        ENV.fetch('MERCADOPAGO_ACCESS_TOKEN', nil)
      end

      def success_url
        Rails.application.routes.url_helpers.booking_url(@booking, host: default_host)
      end

      def failure_url
        Rails.application.routes.url_helpers.booking_url(@booking, host: default_host)
      end

      def pending_url
        success_url
      end

      def webhook_url
        Rails.application.routes.url_helpers.payments_webhooks_mercadopago_url(host: default_host)
      end

      def default_host
        ENV.fetch('APP_HOST', 'localhost:3000')
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
