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
    params = space_checkout_params_for_mode(space, mode, date, checkout_params, user: user)
    Bookings::Quote.new(space: space, params: params, user: user).call
  end

  def space_checkout_params_for_mode(space, mode, date, checkout_params, user: nil)
    params = checkout_params.to_h.stringify_keys.slice('start_time', 'slot_count', 'slot_rate_id')
    params['reservation_mode'] = mode
    params['date'] = date.to_date.iso8601

    case mode
    when 'hora'
      params['slot_count'] = params['slot_count'].presence || space.minimum_slots
      if params['start_time'].blank?
        params['start_time'] = space_booking_start_time_options(space, date, for_user: user).first&.last
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

  def space_bloque_rate_time_range(space, rate, date)
    labels = space.bloque_window_labels_for_date(date, rate)
    "#{labels[:start]}–#{labels[:end]}"
  end

  def space_checkout_start_time_options(space, date, user: nil)
    selectable_schedule_blocks_on(space, date, for_user: user).map do |block|
      d = date.to_date
      start_label = block.starts_at_on(d).strftime('%H:%M')
      end_label = block.ends_at_on(d).strftime('%H:%M')
      ["#{start_label} – #{end_label}", start_label]
    end
  end

  def space_checkout_mode_values(space)
    space_checkout_modes(space).map { |m| m[:value] }
  end

  def space_booking_prefill_path(space, **params)
    raw = params.stringify_keys
    query = raw.slice('date', 'start_time', 'slot_count', 'hours', 'reservation_mode', 'slot_rate_id').compact
    equipment_ids = raw['rented_equipment_item_ids'] || params[:rented_equipment_item_ids]
    if equipment_ids.present?
      query['rented_equipment_item_ids'] = Array(equipment_ids).map(&:to_s)
    end
    space_path(space, query)
  end

  def space_slot_checkout_path(space, date:, start_time:)
    space_booking_prefill_path(
      space,
      date: date.to_date.iso8601,
      start_time: start_time,
      reservation_mode: "hora",
      slot_count: space.minimum_slots
    )
  end

  def space_bloque_checkout_path(space, date:, slot_rate:)
    space_booking_prefill_path(
      space,
      date: date.to_date.iso8601,
      reservation_mode: "bloque",
      slot_rate_id: slot_rate.id
    )
  end

  def space_jornada_checkout_path(space, date:)
    space_booking_prefill_path(
      space,
      date: date.to_date.iso8601,
      reservation_mode: "jornada"
    )
  end

  def space_availability_view_modes(space)
    modes = [{ value: "hora", title: "Por hora" }]
    modes << { value: "bloque", title: "Por bloque" } if space.offers_bloque_reservation?
    modes << { value: "jornada", title: "Por día" } if space.primary_jornada_definition.present?
    modes
  end

  def space_availability_schedule_frame_data(space, payload, availability_url: nil, form_controller: nil,
                                             sync_booking_form: true)
    {
      controller: 'availability-schedule',
      availability_schedule_loading_class: 'opacity-50 pointer-events-none',
      availability_schedule_space_id_value: space.id,
      availability_schedule_weeks_value: payload[:weeks].to_json,
      availability_schedule_initial_week_start_value: payload[:initialWeekStart],
      availability_schedule_interactive_value: payload[:interactive],
      availability_schedule_login_prompt_value: payload[:loginPrompt],
      availability_schedule_availability_url_value: availability_url || availability_space_path(space),
      availability_schedule_form_controller_value: form_controller,
      availability_schedule_sync_booking_form_value: sync_booking_form
    }.compact
  end

  # Calendar views should use day[:bloque] / day[:jornada] from AvailabilityScheduleBuilder.
  def space_availability_bloque_entries(space, date)
    return [] if date.to_date < Date.current

    checker = AvailabilityChecker.new(space)
    space.bloque_slot_rates.map do |rate|
      {
        rate: rate,
        available: checker.slot_rate_window_available?(date, rate)
      }
    end
  end

  def space_availability_jornada_entry(space, date)
    jornada = space.primary_jornada_definition
    return nil unless jornada
    return nil if date.to_date < Date.current

    checker = AvailabilityChecker.new(space)
    {
      jornada: jornada,
      available: checker.jornada_window_available?(date, jornada)
    }
  end

  def space_booking_blocks_by_day(space)
    blocks = if space.association(:schedule_blocks).loaded?
               space.schedule_blocks.sort_by { |b| [b.position, b.start_time] }
             else
               space.schedule_blocks.ordered.to_a
             end
    blocks.group_by(&:day_of_week).transform_values do |day_blocks|
      day_blocks.map do |b|
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

  def space_booking_start_time_options(space, date, for_user: nil)
    selectable_schedule_blocks_on(space, date, for_user: for_user).map do |block|
      d = date.to_date
      start_label = block.starts_at_on(d).strftime('%H:%M')
      end_label = block.ends_at_on(d).strftime('%H:%M')
      price = block.price_cents_on(d)
      ["#{start_label} – #{end_label} (#{format_clp(price)})", start_label]
    end
  end

  def selectable_schedule_blocks_on(space, date, for_user: nil)
    d = date.to_date
    reserved = space_booking_reserved_intervals(space, for_user: for_user)

    space.bookable_schedule_blocks_on(d).reject do |block|
      start_at = block.starts_at_on(d)
      end_at = block.ends_at_on(d)
      reserved_interval_overlaps?(start_at, end_at, reserved)
    end
  end

  def space_selectable_bloque_slot_rates(space, date, for_user: nil)
    d = date.to_date
    checker = AvailabilityChecker.new(space)
    space.bloque_slot_rates.select { |rate| checker.slot_rate_window_available?(d, rate) }
  end

  def reserved_interval_overlaps?(start_at, end_at, reserved_intervals)
    reserved_intervals.any? do |interval|
      interval_start = Time.zone.parse(interval[:start].to_s)
      interval_end = Time.zone.parse(interval[:end].to_s)
      interval_start < end_at && interval_end > start_at
    end
  end

  def space_booking_block_overrides(space)
    records = if space.association(:schedule_block_overrides).loaded?
                space.schedule_block_overrides.select { |o| o.date >= Date.current }
              else
                space.schedule_block_overrides.where('date >= ?', Date.current)
              end

    records.map do |o|
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

  def space_booking_reserved_intervals(space, for_user: nil)
    scope = space.bookings.blocking_availability.where('end_at >= ?', Time.current)
    if for_user
      own_pending = space.bookings.blocking_availability
                         .where(renter_id: for_user.id, status: :pending_payment)
      scope = scope.where.not(id: own_pending.select(:id))
    end

    scope.pluck(:start_at, :end_at).map do |start_at, end_at|
      {
        start: start_at.iso8601,
        end: end_at.iso8601
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
