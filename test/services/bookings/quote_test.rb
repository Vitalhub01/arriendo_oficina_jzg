# frozen_string_literal: true

require 'test_helper'

module Bookings
  class QuoteTest < ActiveSupport::TestCase
    setup do
      @space = boxes(:published_box)
      @slot_time = next_monday_at(hour: 10)
    end

    test 'quotes hourly reservation with string params' do
      result = Quote.new(
        space: @space,
        params: {
          'date' => @slot_time.to_date.iso8601,
          'start_time' => '10:00',
          'reservation_mode' => 'hora',
          'slot_count' => '2'
        }
      ).call

      assert result.success?
      assert_equal 30_000, result.total_cents
    end
  end
end
