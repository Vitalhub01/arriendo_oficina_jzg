# frozen_string_literal: true

module SpaceScheduleWeeks
  extend ActiveSupport::Concern

  PRELOAD_WEEKS = 5

  private

  def load_space_schedule(space)
    @week_start = schedule_week_start(space)
    @schedule_week_entries = AvailabilityScheduleBuilder.new(
      space,
      week_start: @week_start,
      week_count: PRELOAD_WEEKS
    ).build_weeks
    @schedule = @schedule_week_entries.first[:schedule]
  end

  def schedule_week_start(space)
    if params[:week_start].present?
      Date.parse(params[:week_start]).beginning_of_week(:monday)
    else
      space.preferred_schedule_week_start
    end
  rescue ArgumentError
    space.preferred_schedule_week_start
  end
end
