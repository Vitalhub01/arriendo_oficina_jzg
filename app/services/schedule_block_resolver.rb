# frozen_string_literal: true

class ScheduleBlockResolver
  def self.blocks_for_exact_interval(space, start_at, end_at)
    new(space).blocks_for_exact_interval(start_at, end_at)
  end

  def self.consecutive_blocks_from(space, start_at, block_count)
    new(space).consecutive_blocks_from(start_at, block_count)
  end

  def initialize(space)
    @space = space
  end

  def blocks_for_exact_interval(start_at, end_at)
    return [] unless start_at && end_at && end_at > start_at

    date = start_at.to_date
    return [] if end_at.to_date != date

    day_blocks = @space.schedule_blocks_for_date(date)
    result = []
    current = start_at

    while current < end_at
      block = day_blocks.find { |b| b.starts_at_on(date) == current }
      return [] unless block

      block_end = block.ends_at_on(date)
      return [] if block_end > end_at

      result << block
      current = block_end
    end

    return [] unless current == end_at

    result
  end

  def consecutive_blocks_from(start_at, block_count)
    date = start_at.to_date
    day_blocks = @space.schedule_blocks_for_date(date)
    start_index = day_blocks.index { |b| b.starts_at_on(date) == start_at }
    return [] if start_index.nil?

    selected = day_blocks[start_index, block_count] || []
    return [] unless selected.size == block_count

    contiguous = selected.each_cons(2).all? do |a, b|
      a.ends_at_on(date) == b.starts_at_on(date)
    end

    contiguous ? selected : []
  end

  def interval_matches_schedule?(start_at, end_at)
    interval_covers_schedule?(start_at, end_at)
  end

  def interval_covers_schedule?(start_at, end_at)
    blocks = blocks_for_exact_interval(start_at, end_at)
    return false if blocks.empty?

    date = start_at.to_date
    blocks.first.starts_at_on(date) == start_at && blocks.last.ends_at_on(date) == end_at
  end
end
