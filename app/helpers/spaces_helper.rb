# frozen_string_literal: true

module SpacesHelper
  def space_slot_checkout_path(space, date:, start_time:)
    checkout_space_path(
      space,
      date: date.to_date.iso8601,
      start_time: start_time,
      reservation_mode: "hora",
      slot_count: space.minimum_slots
    )
  end

  def space_booking_blocks_by_day(space)
    space.schedule_blocks.ordered.group_by(&:day_of_week).transform_values do |blocks|
      blocks.map do |b|
        {
          id: b.id,
          start: b.start_time.strftime('%H:%M'),
          end: b.end_time.strftime('%H:%M'),
          price: b.price_cents,
          duration: b.duration_minutes,
          effective_until: b.effective_until&.iso8601
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

  def space_booking_slot_rates_payload(space)
    space.slot_rates.ordered.map do |rate|
      {
        id: rate.id,
        name: rate.name,
        start: rate.start_time.strftime('%H:%M'),
        end: rate.end_time.strftime('%H:%M'),
        hourly_price: rate.price_per_slot_cents,
        block_price: rate.block_price_cents_effective
      }
    end
  end

  def space_booking_reserved_intervals(space)
    space.bookings.blocking_availability.where('end_at >= ?', Time.current).map do |booking|
      {
        start: booking.start_at.iso8601,
        end: booking.end_at.iso8601
      }
    end
  end

  def space_booking_jornada_payload(space)
    jornada = space.primary_jornada_definition
    return nil unless jornada

    {
      id: jornada.id,
      name: jornada.name,
      start: jornada.start_time.strftime('%H:%M'),
      end: jornada.end_time.strftime('%H:%M'),
      price: jornada.price_cents
    }
  end
end
