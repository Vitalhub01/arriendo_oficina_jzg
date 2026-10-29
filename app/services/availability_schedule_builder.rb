# frozen_string_literal: true

class AvailabilityScheduleBuilder
  Slot = Struct.new(:starts_at, :ends_at, :price_cents, :available, keyword_init: true)

  def initialize(box, week_start:, week_count: 1, exclude_renter_id: nil)
    @box = box
    @week_start = week_start.to_date.beginning_of_week(:monday)
    @week_count = week_count.to_i
    @week_count = 1 if @week_count < 1
    @range_end_date = @week_start + (@week_count * 7 - 1).days
    @exclude_renter_id = exclude_renter_id
  end

  def build
    build_weeks.first[:schedule]
  end

  def build_weeks
    preload!

    (0...@week_count).map do |week_offset|
      week_start = @week_start + week_offset.weeks
      schedule = (0..6).map do |day_offset|
        build_day(week_start + day_offset.days, day_offset)
      end
      { week_start: week_start, schedule: schedule }
    end
  end

  private

  attr_reader :box

  def preload!
    return if @preloaded

    range_start = @week_start.beginning_of_day
    range_end = @range_end_date.end_of_day

    @overrides_by_block_and_date = ScheduleBlockOverride
                                     .where(space: box, date: @week_start..@range_end_date)
                                     .index_by { |override| [override.schedule_block_id, override.date] }

    blocking_scope = box.bookings.blocking_availability
                        .where('start_at < ? AND end_at > ?', range_end, range_start)
    blocking_scope = blocking_scope.where.not(renter_id: @exclude_renter_id) if @exclude_renter_id
    @blocking_bookings = blocking_scope.pluck(:start_at, :end_at)

    @availability_blocks = box.availability_blocks
                              .where('start_at < ? AND end_at > ?', range_end, range_start)
                              .pluck(:start_at, :end_at)

    @schedule_blocks_by_day = schedule_blocks_grouped_by_day
    @bloque_slot_rates = bloque_slot_rates_for_box
    @primary_jornada = primary_jornada_for_box

    @preloaded = true
  end

  def schedule_blocks_grouped_by_day
    if box.association(:schedule_blocks).loaded?
      box.schedule_blocks.sort_by { |block| [block.position, block.start_time] }.group_by(&:day_of_week)
    else
      box.schedule_blocks.ordered.group_by(&:day_of_week)
    end
  end

  def bloque_slot_rates_for_box
    bloque_names = SpaceBlockPeriods::PERIODS.map { |period| period[:name] }
    rates = if box.association(:slot_rates).loaded?
              box.slot_rates.select { |rate| bloque_names.include?(rate.name) }
            else
              box.bloque_slot_rates.to_a
            end
    rates.sort_by { |rate| [rate.position, rate.start_time] }
  end

  def primary_jornada_for_box
    if box.association(:jornada_definitions).loaded?
      box.jornada_definitions.select(&:active?).min_by { |j| [j.position, j.id] }
    else
      box.primary_jornada_definition
    end
  end

  def build_day(date, day_offset)
    {
      date: date,
      day_name: AvailabilityRule::DAY_NAMES[day_offset],
      slots: slots_for(date),
      bloque: bloque_entries_for(date),
      jornada: jornada_entry_for(date)
    }
  end

  def bloque_entries_for(date)
    return [] if date.to_date < Date.current
    return [] if @bloque_slot_rates.empty?

    @bloque_slot_rates.map do |rate|
      {
        rate: rate,
        available: slot_rate_window_available?(date, rate)
      }
    end
  end

  def jornada_entry_for(date)
    return nil unless @primary_jornada
    return nil if date.to_date < Date.current

    {
      jornada: @primary_jornada,
      available: jornada_window_available?(date, @primary_jornada)
    }
  end

  def slot_rate_window_available?(date, slot_rate)
    blocks = schedule_blocks_within_time_range(date, slot_rate.start_time, slot_rate.end_time)
    period_window_available?(date, blocks)
  end

  def jornada_window_available?(date, jornada_definition)
    blocks = schedule_blocks_within_time_range(date, jornada_definition.start_time, jornada_definition.end_time)
    period_window_available?(date, blocks)
  end

  def schedule_blocks_within_time_range(date, range_start_time, range_end_time)
    schedule_blocks_for_date(date).select do |block|
      block.start_time >= range_start_time && block.end_time <= range_end_time
    end
  end

  def period_window_available?(date, blocks)
    return false if blocks.empty?
    return false unless contiguous_blocks?(date, blocks)

    blocks.all? do |block|
      slot_available?(starts_at_on(block, date), ends_at_on(block, date))
    end
  end

  def contiguous_blocks?(date, blocks)
    blocks.each_cons(2).all? do |left, right|
      ends_at_on(left, date) == starts_at_on(right, date)
    end
  end

  def slots_for(date)
    blocks = schedule_blocks_for_date(date)
    return [] if blocks.empty?

    now = Time.current
    blocks.filter_map do |block|
      next if date < Date.current

      slot_start = starts_at_on(block, date)
      slot_end = ends_at_on(block, date)
      next if slot_start < now

      Slot.new(
        starts_at: slot_start,
        ends_at: slot_end,
        price_cents: price_cents_on(block, date),
        available: slot_available?(slot_start, slot_end)
      )
    end
  end

  def schedule_blocks_for_date(date)
    day = (date.wday + 6) % 7
    blocks = @schedule_blocks_by_day[day] || []
    blocks.reject { |block| !active_on?(block, date) || blocked_on?(block, date) }
  end

  def active_on?(block, date)
    d = date.to_date
    block.effective_until.blank? || d <= block.effective_until
  end

  def blocked_on?(block, date)
    override_for(block, date)&.blocked?
  end

  def override_for(block, date)
    @overrides_by_block_and_date[[block.id, date.to_date]]
  end

  def price_cents_on(block, date)
    override = override_for(block, date)
    return block.price_cents unless override&.price_cents.present?

    override.price_cents
  end

  def starts_at_on(block, date)
    time = override_for(block, date)&.start_time.presence || block.start_time
    time_on_date(date, time)
  end

  def ends_at_on(block, date)
    time = override_for(block, date)&.end_time.presence || block.end_time
    time_on_date(date, time)
  end

  def time_on_date(date, time)
    Time.zone.local(date.year, date.month, date.day, time.hour, time.min, time.sec)
  end

  def slot_available?(start_at, end_at)
    !interval_overlaps?(@blocking_bookings, start_at, end_at) &&
      !interval_overlaps?(@availability_blocks, start_at, end_at)
  end

  def interval_overlaps?(intervals, start_at, end_at)
    intervals.any? { |blocked_start, blocked_end| blocked_start < end_at && blocked_end > start_at }
  end
end
