# frozen_string_literal: true

class SpacesController < ApplicationController
  def index
    @spaces = Space.published_spaces.includes(space_photos: { image_attachment: :blob })
    @spaces = @spaces.by_city(params[:city]) if params[:city].present?
    @spaces = @spaces.by_commune(params[:commune]) if params[:commune].present?
    @spaces = @spaces.by_type(params[:space_type]) if params[:space_type].present?
    @spaces = @spaces.by_min_price(params[:min_price]) if params[:min_price].present?
    @spaces = @spaces.by_max_price(params[:max_price]) if params[:max_price].present?
    @spaces = @spaces.order(created_at: :desc)

    @filtered_by_availability = false
    if params[:date].present? && (params[:slot_count].present? || params[:hours].present?)
      @filtered_by_availability = true
      slot_count = (params[:slot_count] || params[:hours]).to_i
      start_at, end_at = availability_window(
        date: params[:date],
        slot_count: slot_count,
        start_time: params[:start_time] || '09:00',
        slot_duration_minutes: params[:slot_duration_minutes]
      )
      spaces_list = @spaces.select { |space| AvailabilityChecker.new(space).available?(start_at, end_at) }
      @pagy, @spaces = pagy_array(spaces_list)
    else
      @pagy, @spaces = pagy(@spaces)
    end
    @map_spaces = @spaces.select { |s| s.latitude.present? && s.longitude.present? }
  end

  def show
    @space = Space.published_spaces
                  .includes(space_photos: { image_attachment: :blob })
                  .find(params.expect(:id))
    authorize @space
    @week_start = schedule_week_start(@space)
    @schedule = AvailabilityScheduleBuilder.new(@space, week_start: @week_start).build
    @prefill_date = params[:date]
    @prefill_slot_count = params[:slot_count] || params[:hours]
    @prefill_start_time = params[:start_time]
  end

  def availability
    @space = Space.published_spaces
                  .includes(space_photos: { image_attachment: :blob })
                  .find(params.expect(:id))
    @week_start = schedule_week_start(@space)
    @schedule = AvailabilityScheduleBuilder.new(@space, week_start: @week_start).build
    render partial: 'spaces/availability_schedule',
           locals: {
             space: @space,
             schedule: @schedule,
             week_start: @week_start,
             interactive: user_signed_in? && current_user.can_book?
           }
  end

  private

  def schedule_week_start(space)
    if params[:week_start].present?
      Date.parse(params[:week_start]).beginning_of_week(:monday)
    else
      space.preferred_schedule_week_start
    end
  rescue ArgumentError
    space.preferred_schedule_week_start
  end

  def availability_window(date:, slot_count:, start_time:, slot_duration_minutes: nil)
    parsed_date = Date.parse(date.to_s)
    hour, min = start_time.to_s.split(':').map(&:to_i)
    start_at = Time.zone.local(parsed_date.year, parsed_date.month, parsed_date.day, hour, min)
    duration = (slot_duration_minutes.presence || 60).to_i * slot_count.to_i
    end_at = start_at + duration.minutes
    [start_at, end_at]
  end
end
