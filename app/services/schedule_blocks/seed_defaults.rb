# frozen_string_literal: true

module ScheduleBlocks
  # Plantilla semanal inicial al crear un espacio: bloques de 1 h según slot_duration_minutes.
  # Mañana lun–sáb 08:00–14:00; tarde lun–vie 14:00–20:00; sáb tarde 14:00–16:00.
  class SeedDefaults
    Result = Struct.new(:success, :errors, keyword_init: true) do
      def success?
        success
      end
    end

    MORNING_DAYS = (0..5).freeze
    AFTERNOON_WEEKDAYS = (0..4).freeze
    SATURDAY = 5

    RANGES = [
      { days: MORNING_DAYS, start_time: '08:00', end_time: '14:00' },
      { days: AFTERNOON_WEEKDAYS, start_time: '14:00', end_time: '20:00' },
      { days: [SATURDAY], start_time: '14:00', end_time: '16:00' }
    ].freeze

    def self.call(space)
      new(space).call
    end

    def initialize(space)
      @space = space
    end

    def call
      return Result.new(success: true, errors: []) if @space.schedule_blocks.exists?

      ApplicationRecord.transaction do
        RANGES.each do |range|
          failure = fill_range(range)
          return failure if failure
        end
      end

      Result.new(success: true, errors: [])
    end

    private

    def fill_range(range)
      result = BulkFill.call(
        space: @space,
        days: range[:days],
        start_time: range[:start_time],
        end_time: range[:end_time],
        replace_overlapping: false
      )
      return if result.success?

      Result.new(success: false, errors: result.errors)
    end
  end
end
