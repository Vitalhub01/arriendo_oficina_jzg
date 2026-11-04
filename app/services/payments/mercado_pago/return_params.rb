# frozen_string_literal: true

module Payments
  module MercadoPago
    module ReturnParams
      def self.return?(params)
        hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
        hash = hash.with_indifferent_access

        hash[:collection_status].present? ||
          hash[:payment_id].present? ||
          hash[:status].present? ||
          hash[:preference_id].present?
      end
    end
  end
end
