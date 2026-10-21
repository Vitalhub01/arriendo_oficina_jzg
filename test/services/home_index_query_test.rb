# frozen_string_literal: true

require 'test_helper'

class HomeIndexQueryTest < ActiveSupport::TestCase
  test 'home pricing uses aggregate queries not per-space loads' do
    queries = []
    subscriber = lambda do |*_args, payload|
      queries << payload[:sql] if payload[:sql].present?
    end

    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      HomeIndexQuery.call
    end

    select_queries = queries.grep(/\ASELECT/i)
    assert select_queries.count < 25, "expected fewer SELECTs, got #{select_queries.count}"
    assert select_queries.any? { |sql| sql.include?('MIN') }, 'expected aggregate pricing query'
  end
end
