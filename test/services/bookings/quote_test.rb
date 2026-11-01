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

    test 'adds equipment rental per hour to quote total' do
      item = equipment_items(:wifi_equipment)
      item.update_columns(price_per_hour_cents: 500)

      result = Quote.new(
        space: @space,
        user: users(:renter),
        params: {
          'date' => @slot_time.to_date.iso8601,
          'start_time' => '10:00',
          'reservation_mode' => 'hora',
          'slot_count' => '2',
          'rented_equipment_item_ids' => [item.id]
        }
      ).call

      assert result.success?
      assert_equal 31_000, result.total_cents
    end

    test 'adds equipment rental to bloque quote' do
      item = equipment_items(:wifi_equipment)
      item.update_columns(price_per_hour_cents: 1000)
      morning = @space.bloque_slot_rates.find_by!(name: 'Mañana')

      result = Quote.new(
        space: @space,
        user: users(:renter),
        params: {
          'date' => @slot_time.to_date.iso8601,
          'reservation_mode' => 'bloque',
          'slot_rate_id' => morning.id,
          'rented_equipment_item_ids' => [item.id]
        }
      ).call

      assert result.success?
      assert_equal morning.block_price_cents_effective + 6000, result.total_cents
    end

    test 'adds equipment rental to jornada quote as twelve hours' do
      item = equipment_items(:wifi_equipment)
      item.update_columns(price_per_hour_cents: 1000)
      jornada = @space.primary_jornada_definition

      result = Quote.new(
        space: @space,
        user: users(:renter),
        params: {
          'date' => @slot_time.to_date.iso8601,
          'reservation_mode' => 'jornada',
          'rented_equipment_item_ids' => [item.id]
        }
      ).call

      assert result.success?
      assert_equal jornada.price_cents + 12_000, result.total_cents
    end
  end
end
