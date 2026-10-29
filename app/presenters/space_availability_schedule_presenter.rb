# frozen_string_literal: true

class SpaceAvailabilitySchedulePresenter
  include Rails.application.routes.url_helpers

  def initialize(space:, schedule_week_entries:, week_start:, interactive:, login_prompt_on_slots:)
    @space = space
    @schedule_week_entries = schedule_week_entries
    @week_start = week_start.to_date
    @interactive = interactive
    @login_prompt_on_slots = login_prompt_on_slots
  end

  def as_json
    {
      weeks: @schedule_week_entries.map { |entry| week_payload(entry) },
      initialWeekStart: @week_start.iso8601,
      interactive: @interactive,
      loginPrompt: @login_prompt_on_slots
    }
  end

  private

  attr_reader :space, :interactive, :login_prompt_on_slots

  def week_payload(entry)
    week_start = entry[:week_start].to_date
    prev_week = week_start - 1.week
    next_week = week_start + 1.week
    schedule = entry[:schedule]

    {
      weekStart: week_start.iso8601,
      rangeLabel: week_range_label(week_start),
      prevWeekStart: prev_week.iso8601,
      nextWeekStart: next_week.iso8601,
      showPrevWeek: (prev_week + 6.days) >= Date.current,
      emptyWeek: schedule.sum { |day| day[:slots].size }.zero?,
      days: schedule.map { |day| day_payload(day) }
    }
  end

  def week_range_label(week_start)
    start_label = I18n.l(week_start, format: :short)
    end_label = I18n.l(week_start + 6.days, format: :short)
    "#{start_label} — #{end_label}"
  end

  def day_payload(day)
    date = day[:date].to_date
    {
      date: date.iso8601,
      dayShort: day[:day_name].to_s[0..2],
      dateLabel: I18n.l(date, format: '%d/%m'),
      hora: hora_slots_payload(date, day[:slots]),
      bloque: bloque_payload(date, day[:bloque] || []),
      jornada: jornada_payload(date, day[:jornada])
    }
  end

  def hora_slots_payload(date, slots)
    slots.map do |slot|
      start_label = I18n.l(slot.starts_at, format: '%H:%M')
      end_label = I18n.l(slot.ends_at, format: '%H:%M')
      payload = {
        start: start_label,
        end: end_label,
        available: slot.available
      }
      if login_prompt_on_slots && slot.available
        payload[:checkoutUrl] = space_slot_checkout_path(
          space,
          date: date,
          start_time: start_label
        )
      end
      payload
    end
  end

  def bloque_payload(date, entries)
    entries.map do |entry|
      rate = entry[:rate]
      payload = {
        rateId: rate.id,
        name: rate.name,
        start: rate.start_time.strftime('%H:%M'),
        end: rate.end_time.strftime('%H:%M'),
        available: entry[:available]
      }
      if login_prompt_on_slots && entry[:available]
        payload[:checkoutUrl] = space_bloque_checkout_path(space, date: date, slot_rate: rate)
      end
      payload
    end
  end

  def jornada_payload(date, entry)
    return nil unless entry

    jornada = entry[:jornada]
    payload = {
      available: entry[:available],
      start: jornada.start_time.strftime('%H:%M'),
      end: jornada.end_time.strftime('%H:%M')
    }
    if login_prompt_on_slots && entry[:available]
      payload[:checkoutUrl] = space_jornada_checkout_path(space, date: date)
    end
    payload
  end

  def space_slot_checkout_path(space, date:, start_time:)
    checkout_space_path(
      space,
      date: date.to_date.iso8601,
      start_time: start_time,
      reservation_mode: 'hora',
      slot_count: space.minimum_slots
    )
  end

  def space_bloque_checkout_path(space, date:, slot_rate:)
    checkout_space_path(
      space,
      date: date.to_date.iso8601,
      reservation_mode: 'bloque',
      slot_rate_id: slot_rate.id
    )
  end

  def space_jornada_checkout_path(space, date:)
    checkout_space_path(
      space,
      date: date.to_date.iso8601,
      reservation_mode: 'jornada'
    )
  end
end
