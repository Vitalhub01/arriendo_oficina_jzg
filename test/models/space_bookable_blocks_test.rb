# frozen_string_literal: true

require 'test_helper'

class SpaceBookableBlocksTest < ActiveSupport::TestCase
  setup do
    @space = boxes(:published_box)
  end

  test 'bookable_schedule_blocks_on excludes past starts today' do
    travel_to Time.zone.local(2026, 6, 16, 14, 30, 0) do
      @space.schedule_blocks.for_day(1).destroy_all
      @space.schedule_blocks.create!(
        day_of_week: 1,
        start_time: Time.zone.parse('2000-01-01 08:00'),
        end_time: Time.zone.parse('2000-01-01 09:00'),
        price_cents: 5000,
        position: 0
      )
      @space.schedule_blocks.create!(
        day_of_week: 1,
        start_time: Time.zone.parse('2000-01-01 15:00'),
        end_time: Time.zone.parse('2000-01-01 16:00'),
        price_cents: 5000,
        position: 1
      )

      blocks = @space.bookable_schedule_blocks_on(Date.current)
      assert_equal 1, blocks.size
      assert_equal 15, blocks.first.starts_at_on(Date.current).hour
    end
  end

  test 'bookable_schedule_blocks_on returns all future day blocks' do
    future_monday = 1.week.from_now.to_date.beginning_of_week(:monday)
    blocks = @space.bookable_schedule_blocks_on(future_monday)
    assert_equal @space.schedule_blocks_for_date(future_monday).size, blocks.size
  end

  test 'first_bookable_date skips days without upcoming slots' do
    travel_to Time.zone.local(2026, 6, 14, 10, 0, 0) do
      date = @space.first_bookable_date
      assert @space.bookable_schedule_blocks_on(date).any?
      assert date >= Date.current
    end
  end

  test 'preferred_schedule_week_start advances when current week has no upcoming slots' do
    travel_to Time.zone.local(2026, 6, 19, 20, 0, 0) do # viernes noche
      week = @space.preferred_schedule_week_start
      assert_equal Date.new(2026, 6, 22), week
    end
  end
end
