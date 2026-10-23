# frozen_string_literal: true

module SpaceScheduleWeeks
  extend ActiveSupport::Concern

  PRELOAD_WEEKS = 3

  private

  def load_space_schedule(space)
    @week_start = schedule_week_start(space)
    @schedule = AvailabilityScheduleBuilder.new(space, week_start: @week_start).build
    @schedule_week_entries = (0...PRELOAD_WEEKS).map do |offset|
      week_start = @week_start + offset.weeks
      {
        week_start: week_start,
        schedule: AvailabilityScheduleBuilder.new(space, week_start: week_start).build
      }
    end
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
