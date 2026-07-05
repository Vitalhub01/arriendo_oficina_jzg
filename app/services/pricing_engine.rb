# frozen_string_literal: true

class PricingEngine
  def self.calculate(space, user, booking_type, hours, jornada_definition = nil)
    new(space, user, booking_type, hours, jornada_definition).calculate
  end

  def initialize(space, user, booking_type, hours, jornada_definition = nil)
    @space = space
    @user = user
    @booking_type = booking_type
    @hours = hours.to_i
    @jornada_definition = jornada_definition
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

  attr_reader :space, :user, :booking_type, :hours, :jornada_definition

  def base_subtotal
    if booking_type.to_s == 'jornada' && jornada_definition
      jornada_definition.price_cents
    else
      space.price_for_duration(hours)
    end
  end

  def base_line(amount_cents)
    label = if booking_type.to_s == 'jornada' && jornada_definition
              "Jornada #{jornada_definition.name}"
            else
              "#{hours} hora(s) × #{space.formatted_price_per_hour}"
            end

    { type: 'base', label: label, amount_cents: amount_cents }
  end

  def applicable_rules
    PricingRule.active_rules.select { |rule| rule_applies?(rule) }
  end

  def rule_applies?(rule)
    case rule.rule_type
    when 'volume_discount'
      booking_type.to_s == 'hourly'
    when 'membership_discount'
      user&.active_membership?
    when 'jornada_rate'
      booking_type.to_s == 'jornada' && jornada_definition.present?
    else
      false
    end
  end

  def pricing_context(current_subtotal)
    {
      user: user,
      space: space,
      hours: hours,
      booking_type: booking_type,
      jornada_definition: jornada_definition,
      subtotal_cents: current_subtotal,
      membership_discount_percent: current_membership_discount_percent
    }
  end

  def current_membership_discount_percent
    membership = user&.memberships&.current&.first
    membership&.membership_plan&.discount_percent.to_i
  end
end
