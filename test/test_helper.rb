# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails'
end

ENV['RAILS_ENV'] ||= 'test'
ENV['MERCADOPAGO_ACCESS_TOKEN'] = 'TEST-dummy-token' if ENV['MERCADOPAGO_ACCESS_TOKEN'].blank?
ENV['APP_HOST'] = 'www.example.com' if ENV['APP_HOST'].blank?

require_relative '../config/environment'
require 'minitest/mock'
require 'rails/test_help'
require_relative 'support/integration_helpers'

Minitest::Reporters.use!(Minitest::Reporters::ProgressReporter.new) if defined?(Minitest::Reporters)

module ActiveSupport
  class TestCase
    include IntegrationHelpers

    parallelize(workers: :number_of_processors)

    set_fixture_class boxes: Space
    fixtures :all
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
    include IntegrationHelpers
  end
end
