# frozen_string_literal: true

class PricingEngine
  def self.calculate(space, user, start_at, slot_count, end_at: nil)
    new(space, user, start_at, slot_count, end_at: end_at).calculate
  end

  def initialize(space, user, start_at, slot_count, end_at: nil)
    @space = space
    @user = user
    @start_at = start_at
    @slot_count = slot_count.to_i
    @end_at = end_at
  end

  def calculate
    subtotal_cents = base_subtotal
    breakdown = [base_line(subtotal_cents)]
    discount_cents = 0

    applicable_rules.each do |rule|
      result = rule.apply(pricing_context(subtotal_cents - discount_cents))
      next if result[:discount_cents].to_i <= 0

      discount_cents += result[:discount_cents]
      breakdown << {
        type: rule.rule_type,
        label: result[:label] || rule.name,
        amount_cents: -result[:discount_cents]
      }
    end

    {
      subtotal_cents: subtotal_cents,
      discount_cents: discount_cents,
      total_cents: [subtotal_cents - discount_cents, 0].max,
      breakdown: breakdown
    }
  end

  private

  attr_reader :space, :user, :start_at, :slot_count, :end_at

  def base_subtotal
    interval_end = resolved_end_at
    return space.price_for_interval(start_at, interval_end) if interval_end

    blocks = ScheduleBlockResolver.consecutive_blocks_from(space, start_at, slot_count)
    if blocks.any?
      date = start_at.to_date
      return blocks.sum { |block| block.price_cents_on(date) }
    end

    slot_count.times.sum do |index|
      slot_start = start_at + (index * space.slot_duration_minutes.minutes)
      space.price_per_slot_at(slot_start)
    end
  end

  def resolved_end_at
    return end_at if end_at.present?

    blocks = ScheduleBlockResolver.consecutive_blocks_from(space, start_at, slot_count)
    return nil if blocks.empty?

    date = start_at.to_date
    blocks.last.ends_at_on(date)
  end

  def base_line(amount_cents)
    duration_label = format_duration
    {
      type: 'base',
      label: "#{slot_count} bloque(s) (#{duration_label})",
      amount_cents: amount_cents
    }
  end

  def format_duration
    interval_end = resolved_end_at
    total_minutes = if interval_end
                      ((interval_end - start_at) / 60).to_i
                    else
                      slot_count * space.slot_duration_minutes
                    end
    hours = total_minutes / 60
    minutes = total_minutes % 60
    return "#{hours}h" if minutes.zero?
    return "#{minutes}min" if hours.zero?

    "#{hours}h #{minutes}min"
  end

  def applicable_rules
    PricingRule.active_rules.select do |rule|
      next false if rule.volume_discount? && rule.space_id.present? && rule.space_id != space.id
      next false if rule.membership_discount? && rule.space_id.present?

      rule_applies?(rule)
    end
  end

  def rule_applies?(rule)
    case rule.rule_type
    when 'volume_discount'
      return false if rule.space_id.present? && rule.space_id != space.id

      min_slots = rule.config['min_slots'].to_i
      min_slots = rule.config['min_hours'].to_i if min_slots.zero?
      return false if min_slots.zero?

      slot_count >= min_slots
    when 'membership_discount'
      rule.space_id.nil? && user&.active_membership?
    else
      false
    end
  end

  def pricing_context(current_subtotal)
    {
      user: user,
      space: space,
      slot_count: slot_count,
      hours: duration_hours,
      subtotal_cents: current_subtotal,
      membership_discount_percent: current_membership_discount_percent
    }
  end

  def duration_hours
    interval_end = resolved_end_at
    minutes = if interval_end
                ((interval_end - start_at) / 60).to_i
              else
                slot_count * space.slot_duration_minutes
              end
    minutes / 60.0
  end

  def current_membership_discount_percent
    membership = user&.memberships&.current&.first
    membership&.membership_plan&.discount_percent.to_i
  end
end
