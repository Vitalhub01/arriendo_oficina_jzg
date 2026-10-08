# frozen_string_literal: true

require 'test_helper'

class AvailabilityScheduleBuilderTest < ActiveSupport::TestCase
  setup do
    @space = boxes(:published_box)
    @week_start = Date.current.beginning_of_week(:monday)
  end

  test 'builds slots using space duration' do
    @space.update_column(:slot_duration_minutes, 90)

    schedule = AvailabilityScheduleBuilder.new(@space, week_start: @week_start).build
    monday = schedule.find { |day| day[:day_name] == 'Lunes' }

    assert monday[:slots].any?
    first_slot = monday[:slots].first
    second_slot = monday[:slots][1]
    assert_equal 90, ((second_slot.starts_at - first_slot.starts_at) / 60).to_i
  end
end
