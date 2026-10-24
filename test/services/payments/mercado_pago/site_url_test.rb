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

      test 'production falls back to canonical host when APP_HOST is unset' do
        with_rails_env('production') do
          with_env('APP_HOST' => nil, 'APP_BASE_URL' => nil) do
            with_routes_default_url_options(host: 'www.vitalhub.cl', protocol: 'https') do
              assert_equal 'https://www.vitalhub.cl/membership', SiteUrl.path('/membership')
            end
          end
        end
      end

      test 'production ignores APP_HOST localhost' do
        with_rails_env('production') do
          with_env('APP_HOST' => 'localhost:3000', 'APP_BASE_URL' => nil) do
            with_routes_default_url_options(host: 'www.vitalhub.cl', protocol: 'https') do
              assert_equal 'https://www.vitalhub.cl/membership', SiteUrl.path('/membership')
            end
          end
        end
      end

      test 'production_localhost detects bad back urls' do
        with_rails_env('production') do
          assert SiteUrl.production_localhost?('https://localhost:3000/bookings/1')
          refute SiteUrl.production_localhost?('https://www.vitalhub.cl/bookings/1')
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
        vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
        yield
      ensure
        original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
      end

      def with_routes_default_url_options(options)
        original = Rails.application.routes.default_url_options
        Rails.application.routes.default_url_options = options
        yield
      ensure
        Rails.application.routes.default_url_options = original
      end
    end
  end
end
