# frozen_string_literal: true

module Bookings
  class AdminCalendarBuilder
    Slot = Struct.new(
      :schedule_block_id,
      :starts_at,
      :ends_at,
      :status,
      :booking_ids,
      :label,
      keyword_init: true
    )

    def initialize(space:, week_start:)
      @space = space
      @week_start = week_start.to_date.beginning_of_week(:monday)
      @week_end = @week_start + 6.days
    end

    def build
      load_bookings!

      (0..6).map do |offset|
        date = @week_start + offset.days
        day_of_week = offset
        {
          date: date,
          slots: slots_for(date, day_of_week)
        }
      end
    end

    private

    attr_reader :space

    def load_bookings!
      range_start = @week_start.beginning_of_day
      range_end = @week_end.end_of_day

      @confirmed_bookings = space.bookings.confirmed
                                 .where('start_at < ? AND end_at > ?', range_end, range_start)
                                 .includes(:profesional)
                                 .to_a

      @pending_bookings = space.bookings.pending_payment
                               .where('payment_expires_at IS NULL OR payment_expires_at > ?', Time.current)
                               .where('start_at < ? AND end_at > ?', range_end, range_start)
                               .includes(:profesional)
                               .to_a
    end

    def slots_for(date, day_of_week)
      blocks = space.schedule_blocks.for_day(day_of_week).ordered.select { |block| block.active_on?(date) }

      blocks.map do |block|
        starts_at = block.starts_at_on(date)
        ends_at = block.ends_at_on(date)
        status, bookings = resolve_status_and_bookings(block, date, starts_at, ends_at)

        Slot.new(
          schedule_block_id: block.id,
          starts_at: starts_at,
          ends_at: ends_at,
          status: status,
          booking_ids: bookings.map(&:id),
          label: slot_label(status, bookings, starts_at, ends_at)
        )
      end
    end

    def resolve_status_and_bookings(block, date, starts_at, ends_at)
      if block.blocked_on?(date) || availability_blocked?(starts_at, ends_at)
        return [:blocked, []]
      end

      confirmed = overlapping(@confirmed_bookings, starts_at, ends_at)
      return [:confirmed, confirmed] if confirmed.any?

      pending = overlapping(@pending_bookings, starts_at, ends_at)
      return [:pending, pending] if pending.any?

      [:available, []]
    end

    def availability_blocked?(starts_at, ends_at)
      space.availability_blocks.exists?(['start_at < ? AND end_at > ?', ends_at, starts_at])
    end

    def overlapping(bookings, starts_at, ends_at)
      bookings.select { |b| b.start_at < ends_at && b.end_at > starts_at }
    end

    def slot_label(status, bookings, starts_at, ends_at)
      time_range = "#{starts_at.strftime('%H:%M')}–#{ends_at.strftime('%H:%M')}"
      case status
      when :available
        "#{time_range} · Disponible"
      when :blocked
        "#{time_range} · Bloqueado"
      when :confirmed, :pending
        names = bookings.map { |b| b.profesional.name }.uniq.join(', ')
        state = status == :confirmed ? 'Confirmada' : 'Pendiente de pago'
        "#{time_range} · #{state} — #{names}"
      else
        time_range
      end
    end
  end
end
