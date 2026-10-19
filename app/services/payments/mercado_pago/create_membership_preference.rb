# frozen_string_literal: true

module Payments
  module MercadoPago
    class CreateMembershipPreference
      APPROVED_STATUSES = %w[approved authorized].freeze

      def initialize(user:, membership_plan:)
        @user = user
        @plan = membership_plan
      end

      def call
        return failure('Mercado Pago no configurado') if access_token.blank?

        membership = @user.memberships.create!(
          membership_plan: @plan,
          status: :active,
          starts_at: Time.current,
          expires_at: membership_expires_at
        )

        preference = build_preference(membership)
        sdk = ::Mercadopago::SDK.new(access_token)
        response = sdk.preference.create(preference)

        if response[:status] == 201
          init_point = CheckoutUrl.from_preference(response[:response])
          payment = Payment.create!(
            payer: @user,
            membership: membership,
            payment_kind: :membership,
            mercadopago_preference_id: response.dig(:response, 'id'),
            amount_cents: @plan.price_cents,
            status: :pending
          )
          Result.new(success: true, init_point: init_point, payment: payment)
        else
          membership.destroy
          failure(PreferenceOptions.error_from_response(response) || 'No se pudo crear la preferencia de pago')
        end
      rescue StandardError => e
        failure(e.message)
      end

      private

      def build_preference(membership)
        success_url = SiteUrl.path('/membership')
        {
          items: [{
            title: "Membresía #{@plan.name}",
            quantity: 1,
            unit_price: @plan.price_cents / 100.0,
            currency_id: 'CLP'
          }],
          payer: { email: @user.email },
          external_reference: "membership-#{membership.id}",
          back_urls: {
            success: success_url,
            failure: success_url,
            pending: success_url
          }
        }.merge(PreferenceOptions.auto_return_for(success_url))
      end

      def membership_expires_at
        if @plan.monthly?
          1.month.from_now
        else
          1.year.from_now
        end
      end

      def access_token
        ENV.fetch('MERCADOPAGO_ACCESS_TOKEN', nil)
      end

      def failure(message)
        Result.new(success: false, error: message)
      end

      class Result
        attr_reader :init_point, :payment, :error

        def initialize(success:, init_point: nil, payment: nil, error: nil)
          @success = success
          @init_point = init_point
          @payment = payment
          @error = error
        end

        def success?
          @success
        end
      end
    end
  end
end
