# frozen_string_literal: true

class PricingRule < ApplicationRecord
  enum :rule_type, {
    volume_discount: 0,
    membership_discount: 1,
    jornada_rate: 2
  }

  validates :name, :rule_type, presence: true

  scope :active_rules, -> { where(active: true).order(priority: :desc, created_at: :desc) }

  def apply(context)
    return empty_result unless active?

    case rule_type
    when 'volume_discount'
      apply_volume_discount(context)
    when 'membership_discount'
      apply_membership_discount(context)
    when 'jornada_rate'
      apply_jornada_rate(context)
    else
      empty_result
    end
  end

  private

  def empty_result
    { discount_cents: 0, label: nil }
  end

  def apply_volume_discount(context)
    min_slots = config['min_slots'].to_i
    min_slots = config['min_hours'].to_i if min_slots.zero?

    slot_count = context[:slot_count].to_i
    hours = context[:hours].to_f
    meets_threshold = if slot_count.positive?
                        slot_count >= min_slots
                      else
                        hours >= min_slots
                      end
    return empty_result unless meets_threshold

    percent = config['discount_percent'].to_i
    discount = (context[:subtotal_cents].to_i * percent / 100.0).round

    threshold_label = slot_count.positive? ? "#{min_slots}+ bloques" : "#{min_slots}+ horas"
    {
      discount_cents: discount,
      label: "#{name} (#{percent}% por #{threshold_label})"
    }
  end

  def apply_membership_discount(context)
    return empty_result unless context[:user]&.active_membership?

    percent = config['discount_percent'].presence || context[:membership_discount_percent]
    percent = percent.to_i
    return empty_result if percent <= 0

    discount = (context[:subtotal_cents].to_i * percent / 100.0).round

    {
      discount_cents: discount,
      label: "#{name} (#{percent}% membresía)"
    }
  end

  def apply_jornada_rate(context)
    return empty_result unless context[:booking_type].to_s == 'jornada'
    return empty_result unless context[:jornada_definition]

    jornada_price = context[:jornada_definition].price_cents
    hourly_subtotal = context[:subtotal_cents].to_i
    discount = [hourly_subtotal - jornada_price, 0].max

    {
      discount_cents: discount,
      label: name
    }
  end
end
