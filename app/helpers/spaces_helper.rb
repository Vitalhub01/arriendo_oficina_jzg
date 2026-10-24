# frozen_string_literal: true

module SpacesHelper
  def space_checkout_modes(space, date: Date.current, checkout_params: {}, user: nil)
    booking_date = date.to_date
    modes = [{ value: 'hora', title: 'Hora' }]

    modes << { value: 'bloque', title: 'Bloque' } if space.offers_bloque_reservation?

    modes << { value: 'jornada', title: 'Día' } if space.primary_jornada_definition.present?

    modes.each do |mode|
      mode[:price_label] = space_checkout_mode_price_label(
        space,
        mode[:value],
        date: booking_date,
        checkout_params: checkout_params,
        user: user
      )
    end

    modes
  end

  def space_checkout_mode_price_label(space, mode, date:, checkout_params: {}, user: nil)
    if mode == 'bloque'
      totals = space_checkout_bloque_totals_cents(space, date: date, user: user)
      return nil if totals.empty?

      min = totals.min
      max = totals.max
      return Money.new(min, 'CLP').format(no_cents_if_whole: true) if min == max

      "#{Money.new(min, 'CLP').format(no_cents_if_whole: true)}–#{Money.new(max, 'CLP').format(no_cents_if_whole: true)}"
    end

    quote = space_checkout_mode_quote(space, mode, date: date, checkout_params: checkout_params, user: user)
    quote.success? ? quote.formatted_total : nil
  end

  def space_checkout_mode_quote(space, mode, date:, checkout_params: {}, user: nil)
    params = space_checkout_params_for_mode(space, mode, date, checkout_params)
    Bookings::Quote.new(space: space, params: params, user: user).call
  end

  def space_checkout_params_for_mode(space, mode, date, checkout_params)
    params = checkout_params.to_h.stringify_keys.slice('start_time', 'slot_count', 'slot_rate_id')
    params['reservation_mode'] = mode
    params['date'] = date.to_date.iso8601

    case mode
    when 'hora'
      params['slot_count'] = params['slot_count'].presence || space.minimum_slots
      if params['start_time'].blank?
        params['start_time'] = space_booking_start_time_options(space, date).first&.last
      end
    when 'bloque'
      params['slot_rate_id'] = params['slot_rate_id'].presence || space.bloque_slot_rates.first&.id&.to_s
    end

    params
  end

  def space_checkout_bloque_totals_cents(space, date:, user: nil)
    space.bloque_slot_rates.filter_map do |rate|
      quote = space_checkout_mode_quote(
        space,
        'bloque',
        date: date,
        checkout_params: { slot_rate_id: rate.id },
        user: user
      )
      quote.success? ? quote.total_cents : nil
    end
  end

  def space_checkout_bloque_quote(space, rate, date:, user: nil)
    space_checkout_mode_quote(
      space,
      'bloque',
      date: date,
      checkout_params: { slot_rate_id: rate.id },
      user: user
    )
  end

  def space_checkout_start_time_options(space, date)
    space.bookable_schedule_blocks_on(date).map do |block|
      d = date.to_date
      start_label = block.starts_at_on(d).strftime('%H:%M')
      end_label = block.ends_at_on(d).strftime('%H:%M')
      ["#{start_label} – #{end_label}", start_label]
    end
  end

  def space_checkout_mode_values(space)
    space_checkout_modes(space).map { |m| m[:value] }
  end

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
    space.bloque_slot_rates.map do |rate|
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
