# frozen_string_literal: true

class PricingEngine
  def self.calculate(space, user, start_at, slot_count)
    new(space, user, start_at, slot_count).calculate
  end

  def initialize(space, user, start_at, slot_count)
    @space = space
    @user = user
    @start_at = start_at
    @slot_count = slot_count.to_i
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

  attr_reader :space, :user, :start_at, :slot_count

  def base_subtotal
    slot_count.times.sum do |index|
      slot_start = start_at + (index * space.slot_duration_minutes.minutes)
      space.price_per_slot_at(slot_start)
    end
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
    total_minutes = slot_count * space.slot_duration_minutes
    hours = total_minutes / 60
    minutes = total_minutes % 60
    return "#{hours}h" if minutes.zero?
    return "#{minutes}min" if hours.zero?

    "#{hours}h #{minutes}min"
  end

  def applicable_rules
    PricingRule.active_rules.select { |rule| rule_applies?(rule) }
  end

  def rule_applies?(rule)
    case rule.rule_type
    when 'volume_discount'
      slot_count >= rule.config['min_slots'].to_i
    when 'membership_discount'
      user&.active_membership?
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
    (slot_count * space.slot_duration_minutes) / 60.0
  end

  def current_membership_discount_percent
    membership = user&.memberships&.current&.first
    membership&.membership_plan&.discount_percent.to_i
  end
end
