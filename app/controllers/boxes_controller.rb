# frozen_string_literal: true

class BoxesController < ApplicationController
  def index
    @boxes = Box.published_boxes.includes(photos_attachments: :blob)
    @boxes = @boxes.by_city(params[:city]) if params[:city].present?
    @boxes = @boxes.by_commune(params[:commune]) if params[:commune].present?
    @boxes = @boxes.by_type(params[:box_type]) if params[:box_type].present?
    @boxes = @boxes.by_min_price(params[:min_price]) if params[:min_price].present?
    @boxes = @boxes.by_max_price(params[:max_price]) if params[:max_price].present?
    @boxes = @boxes.order(created_at: :desc)

    if params[:date].present? && params[:hours].present?
      start_at, end_at = availability_window(
        date: params[:date],
        hours: params[:hours],
        start_time: params[:start_time] || '09:00'
      )
      boxes_list = @boxes.select { |box| AvailabilityChecker.new(box).available?(start_at, end_at) }
      @pagy, @boxes = pagy_array(boxes_list)
    else
      @pagy, @boxes = pagy(@boxes)
    end
    @map_boxes = @boxes.select { |b| b.latitude.present? && b.longitude.present? }
  end

  def show
    @box = Box.published_boxes.find(params.expect(:id))
    authorize @box
    @week_start = parse_week_start
    @schedule = AvailabilityScheduleBuilder.new(@box, week_start: @week_start).build
    @prefill_date = params[:date]
    @prefill_hours = params[:hours]
    @prefill_start_time = params[:start_time]
  end

  def availability
    @box = Box.published_boxes.find(params.expect(:id))
    @week_start = parse_week_start
    @schedule = AvailabilityScheduleBuilder.new(@box, week_start: @week_start).build
    render partial: 'boxes/availability_schedule', locals: { box: @box, schedule: @schedule, week_start: @week_start }
  end

  private

  def parse_week_start
    if params[:week_start].present?
      Date.parse(params[:week_start]).beginning_of_week(:monday)
    else
      Date.current.beginning_of_week(:monday)
    end
  rescue ArgumentError
    Date.current.beginning_of_week(:monday)
  end

  def availability_window(date:, hours:, start_time:)
    parsed_date = Date.parse(date.to_s)
    hour, min = start_time.to_s.split(':').map(&:to_i)
    start_at = Time.zone.local(parsed_date.year, parsed_date.month, parsed_date.day, hour, min)
    end_at = start_at + hours.to_i.hours
    [start_at, end_at]
  end
end
