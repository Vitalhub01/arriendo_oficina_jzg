# frozen_string_literal: true

require 'test_helper'

module Payments
  module MercadoPago
    class PreferenceOptionsTest < ActiveSupport::TestCase
      test 'auto_return only for https back urls' do
        assert_equal({ auto_return: 'approved' }, PreferenceOptions.auto_return_for('https://example.com/ok'))
        assert_equal({}, PreferenceOptions.auto_return_for('http://localhost:3000/bookings/1'))
      end

      test 'error_from_response extracts API message' do
        response = { response: { 'message' => 'auto_return invalid', 'error' => 'invalid_auto_return' } }
        assert_includes PreferenceOptions.error_from_response(response), 'auto_return invalid'
      end
    end
  end
end
