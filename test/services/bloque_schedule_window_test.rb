# frozen_string_literal: true

require 'test_helper'

class BloqueScheduleWindowTest < ActiveSupport::TestCase
  setup do
    @space = boxes(:draft_box)
    @space.schedule_blocks.destroy_all
    Spaces::UpsertPricing.new(space: @space, params: admin_pricing_params).call
    ScheduleBlocks::SeedDefaults.call(@space)
  end

  test 'labels reflect actual blocks on short saturday afternoon' do
    date = Date.current.next_occurring(:saturday)
    afternoon = @space.bloque_slot_rates.find_by!(name: 'Tarde')
    blocks = @space.schedule_blocks_within_time_range(date, afternoon.start_time, afternoon.end_time)

    labels = BloqueScheduleWindow.labels_for(
      date,
      blocks,
      fallback_start: afternoon.start_time,
      fallback_end: afternoon.end_time
    )

    assert_equal '14:00', labels[:start]
    assert_equal '16:00', labels[:end]
  end
end
