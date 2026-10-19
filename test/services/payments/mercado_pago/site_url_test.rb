# frozen_string_literal: true

require 'test_helper'

module Payments
  module MercadoPago
    class SiteUrlTest < ActiveSupport::TestCase
      test 'production uses https for paths' do
        with_rails_env('production') do
          with_env('APP_HOST' => 'example.com', 'APP_BASE_URL' => nil) do
            assert_equal 'https://example.com/membership', SiteUrl.path('/membership')
          end
        end
      end

      test 'development localhost uses http unless forced' do
        with_env('APP_HOST' => 'localhost:3000', 'APP_BASE_URL' => nil, 'MERCADOPAGO_HTTPS_BACK_URLS' => nil) do
          assert_equal 'http://localhost:3000/membership', SiteUrl.path('/membership')
        end
      end

      test 'APP_BASE_URL overrides host and protocol' do
        with_env('APP_BASE_URL' => 'https://tunnel.example.dev') do
          assert_equal 'https://tunnel.example.dev/membership', SiteUrl.path('/membership')
        end
      end

      private

      def with_rails_env(env)
        original = Rails.env
        Rails.env = ActiveSupport::StringInquirer.new(env)
        yield
      ensure
        Rails.env = original
      end

      def with_env(vars)
        original = vars.keys.index_with { |k| ENV[k] }
        vars.each { |k, v| ENV[k] = v }
        yield
      ensure
        original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
      end
    end
  end
end
