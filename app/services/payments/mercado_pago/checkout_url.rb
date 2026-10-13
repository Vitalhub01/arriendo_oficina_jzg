# frozen_string_literal: true

module Payments
  module MercadoPago
    module CheckoutUrl
      module_function

      def from_preference(preference)
        return nil unless preference

        if sandbox?
          preference['sandbox_init_point'].presence || preference['init_point']
        else
          preference['init_point']
        end
      end

      def sandbox?
        ENV['MERCADOPAGO_SANDBOX'] == 'true'
      end
    end
  end
end
