# frozen_string_literal: true

module SpaceScheduleWeeks
  extend ActiveSupport::Concern

  PRELOAD_WEEKS = 5

  private

  def load_space_schedule(space, exclude_renter_id: current_user&.id)
    @week_start = schedule_week_start(space)
    @schedule_week_entries = AvailabilityScheduleBuilder.new(
      space,
      week_start: @week_start,
      week_count: PRELOAD_WEEKS,
      exclude_renter_id: exclude_renter_id
    ).build_weeks
    @schedule = @schedule_week_entries.first[:schedule]
    @availability_schedule_payload = SpaceAvailabilitySchedulePresenter.new(
      space: space,
      schedule_week_entries: @schedule_week_entries,
      week_start: @week_start,
      interactive: availability_schedule_interactive?,
      login_prompt_on_slots: availability_schedule_login_prompt?
    ).as_json
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

  def availability_schedule_interactive?
    user_signed_in? && current_user.can_book?
  end

  def availability_schedule_login_prompt?
    !user_signed_in?
  end
end
