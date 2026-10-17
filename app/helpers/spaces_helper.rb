# frozen_string_literal: true

module SpacesHelper
  def space_booking_blocks_by_day(space)
    space.schedule_blocks.ordered.group_by(&:day_of_week).transform_values do |blocks|
      blocks.map do |b|
        {
          id: b.id,
          start: b.start_time.strftime('%H:%M'),
          end: b.end_time.strftime('%H:%M'),
          price: b.price_cents,
          duration: b.duration_minutes
        }
      end
    end
  end

  def space_booking_start_time_options(space, date)
    space.bookable_schedule_blocks_on(date).map do |block|
      d = date.to_date
      start_label = block.starts_at_on(d).strftime('%H:%M')
      end_label = block.ends_at_on(d).strftime('%H:%M')
      price = block.price_cents_on(d)
      ["#{start_label} – #{end_label} (#{format_clp(price)})", start_label]
    end
  end

  def space_booking_block_overrides(space)
    space.schedule_block_overrides.where('date >= ?', Date.current).map do |o|
      {
        schedule_block_id: o.schedule_block_id,
        date: o.date.iso8601,
        blocked: o.blocked,
        price: o.price_cents
      }
    end
  end
end
