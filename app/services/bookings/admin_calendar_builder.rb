# frozen_string_literal: true

module Bookings
  class AdminCalendarBuilder
    Slot = Struct.new(
      :schedule_block_id,
      :schedule_block_ids,
      :starts_at,
      :ends_at,
      :status,
      :booking_ids,
      :label,
      :unblockable,
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

      @cancelled_bookings = space.bookings.cancelled.without_spot_offer
                                 .where('start_at < ? AND end_at > ?', range_end, range_start)
                                 .where.not("pricing_breakdown @> ?", { Bookings::DismissFromAdminCalendar::HIDDEN_KEY => true }.to_json)
                                 .includes(:profesional)
                                 .to_a

      @availability_blocks = space.availability_blocks
                                  .where('end_at > ? AND start_at < ?', range_start, range_end)
                                  .to_a
    end

    def slots_for(date, day_of_week)
      blocks = space.schedule_blocks.for_day(day_of_week).ordered.select { |block| block.active_on?(date) }
      blocks = ScheduleBlock.sort_for_display_on(blocks, date)

      slots = blocks.map do |block|
        starts_at = block.starts_at_on(date)
        ends_at = block.ends_at_on(date)
        status, bookings, unblockable = resolve_status_and_bookings(block, date, starts_at, ends_at)

        Slot.new(
          schedule_block_id: block.id,
          schedule_block_ids: [block.id],
          starts_at: starts_at,
          ends_at: ends_at,
          status: status,
          booking_ids: bookings.map(&:id),
          label: slot_label(status, bookings, starts_at, ends_at),
          unblockable: unblockable
        )
      end

      merge_adjacent_slots(slots)
    end

    def resolve_status_and_bookings(block, date, starts_at, ends_at)
      if block.blocked_on?(date)
        return [:blocked, [], true]
      end

      if availability_blocked?(starts_at, ends_at)
        return [:blocked, [], false]
      end

      confirmed = overlapping(@confirmed_bookings, starts_at, ends_at)
      return [:confirmed, confirmed, false] if confirmed.any?

      pending = overlapping(@pending_bookings, starts_at, ends_at)
      return [:pending, pending, false] if pending.any?

      cancelled = overlapping(@cancelled_bookings, starts_at, ends_at)
      return [:cancelled, cancelled, false] if cancelled.any?

      [:available, [], false]
    end

    def availability_blocked?(starts_at, ends_at)
      @availability_blocks.any? { |block| block.start_at < ends_at && block.end_at > starts_at }
    end

    def merge_adjacent_slots(slots)
      slots.each_with_object([]) do |slot, merged|
        if merged.last && mergeable?(merged.last, slot)
          merged[-1] = combine_slots(merged.last, slot)
        else
          merged << slot
        end
      end
    end

    def mergeable?(left, right)
      return false unless left.ends_at == right.starts_at
      return false unless left.status == right.status

      case left.status
      when :available
        false
      when :blocked
        left.unblockable == right.unblockable
      when :confirmed, :pending, :cancelled
        left.booking_ids.sort == right.booking_ids.sort && left.booking_ids.any?
      else
        false
      end
    end

    def combine_slots(first, second)
      bookings = bookings_for_ids(first.booking_ids)
      Slot.new(
        schedule_block_id: first.schedule_block_id,
        schedule_block_ids: first.schedule_block_ids + second.schedule_block_ids,
        starts_at: first.starts_at,
        ends_at: second.ends_at,
        status: first.status,
        booking_ids: first.booking_ids,
        label: slot_label(first.status, bookings, first.starts_at, second.ends_at),
        unblockable: first.unblockable
      )
    end

    def bookings_for_ids(ids)
      return [] if ids.empty?

      ids.filter_map { |id| booking_index[id] }
    end

    def booking_index
      @booking_index ||= begin
        index = {}
        (@confirmed_bookings + @pending_bookings + @cancelled_bookings).each do |booking|
          index[booking.id] = booking
        end
        index
      end
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
      when :cancelled
        names = bookings.map { |b| b.profesional.name }.uniq.join(', ')
        "#{time_range} · Anulada — #{names}"
      else
        time_range
      end
    end
  end
end
