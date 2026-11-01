# frozen_string_literal: true

class Booking < ApplicationRecord
  include OverlapCheckable

  attr_accessor :reservation_slot_rate, :reservation_mode, :rented_equipment_item_ids

  belongs_to :space, class_name: 'Space', foreign_key: :box_id, inverse_of: :bookings
  belongs_to :profesional, class_name: 'User', foreign_key: :renter_id, inverse_of: :bookings
  alias_attribute :profesional_id, :renter_id
  belongs_to :booking_series, optional: true
  belongs_to :jornada_definition, optional: true
  belongs_to :reschedule_credit, optional: true
  belongs_to :discount_code, optional: true
  belongs_to :spot_offer, optional: true
  has_one :payment, dependent: :destroy
  has_one :testimonial, dependent: :destroy

  enum :status, { pending_payment: 0, confirmed: 1, cancelled: 2, completed: 3, rescheduled: 4 }
  enum :booking_type, { hourly: 0, jornada: 1, slot_based: 2 }

  validates :start_at, :end_at, :duration_minutes, presence: true
  validates :duration_minutes, numericality: { greater_than: 0, only_integer: true }
  validates :total_amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :reschedule_modifications_count,
            numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :minimum_slots_met, on: :create
  validate :availability_check, on: :create
  validate :start_at_not_in_past, on: :create

  before_validation :set_payment_expires_at, on: :create
  before_validation :set_duration_and_amount, on: :create
  before_validation :apply_reschedule_credit_deduction, on: :create

  scope :upcoming, -> { where(start_at: Time.current..).order(:start_at) }
  scope :starting_on_date, lambda { |date|
    day = date.is_a?(Date) ? date : Date.parse(date.to_s)
    range_start = Time.zone.local(day.year, day.month, day.day).beginning_of_day
    where(start_at: range_start..range_start.end_of_day)
  }
  scope :excluding_cancelled, -> { where.not(status: :cancelled) }
  scope :without_spot_offer, -> { where(spot_offer_id: nil) }
  scope :active_statuses, -> { where(status: %i[pending_payment confirmed]) }
  scope :blocking_availability, lambda {
    where(status: :confirmed).or(
      where(status: :pending_payment).where('payment_expires_at IS NULL OR payment_expires_at > ?', Time.current)
    )
  }
  scope :payment_expired, lambda {
    pending_payment.where(payment_expires_at: ..Time.current)
  }

  def self.payment_ttl
    ENV.fetch('BOOKING_PAYMENT_TTL_MINUTES', '30').to_i.minutes
  end

  def payment_expired?
    pending_payment? && payment_expires_at.present? && payment_expires_at <= Time.current
  end

  def formatted_total
    Money.new(total_amount_cents, 'CLP').format(no_cents_if_whole: true)
  end

  def spot_offer_booking?
    spot_offer_id.present?
  end

  def spot_package_paid?
    spot_offer_booking? && spot_offer.paid?
  end

  def spot_package_session_index
    return unless spot_offer_booking?

    ids = spot_offer.bookings.order(:start_at, :id).pluck(:id)
    position = ids.index(id)
    position ? position + 1 : nil
  end

  def spot_package_sessions_count
    return unless spot_offer_booking?

    spot_offer.bookings.size
  end

  def spot_package_total_cents
    spot_offer&.total_price_cents.to_i
  end

  def formatted_spot_package_total
    Money.new(spot_package_total_cents, 'CLP').format(no_cents_if_whole: true)
  end

  def pricing_subtotal_cents
    pricing_breakdown&.dig('subtotal_cents').to_i
  end

  def applied_reschedule_credit_cents
    reschedule_credit&.amount_cents.to_i
  end

  def reservation_value_cents
    subtotal = pricing_subtotal_cents
    return subtotal if subtotal.positive?

    total_amount_cents + promo_discount_cents.to_i + applied_reschedule_credit_cents
  end

  def formatted_reservation_value
    Money.new(reservation_value_cents, 'CLP').format(no_cents_if_whole: true)
  end

  def formatted_applied_reschedule_credit
    return unless applied_reschedule_credit_cents.positive?

    Money.new(applied_reschedule_credit_cents, 'CLP').format(no_cents_if_whole: true)
  end

  def slot_count
    return 0 unless space && start_at && end_at

    count = space.schedule_block_count_for_interval(start_at, end_at)
    return count if count.positive?

    return 0 unless duration_minutes.to_i.positive?

    duration_minutes / space.slot_duration_minutes
  end

  def display_hours
    (duration_minutes.to_f / 60).round(1)
  end

  def formatted_duration
    total_minutes = duration_minutes
    hours_part = total_minutes / 60
    minutes_part = total_minutes % 60
    return "#{hours_part} hora(s)" if minutes_part.zero?

    "#{hours_part}h #{minutes_part}min"
  end

  def box
    space
  end

  def reschedule_notice_hours
    hours = space.reschedule_notice_hours
    if hours.blank?
      hours = SiteSetting.get('reschedule_notice_hours', ENV.fetch('RESCHEDULE_NOTICE_HOURS', '12')).to_i
    end
    hours.to_i
  end

  def reschedule_modifications_remaining
    [Bookings::Reschedule::MAX_MODIFICATIONS - reschedule_modifications_count, 0].max
  end

  def reschedule_replacement?
    reschedule_credit_id.present? && reschedule_credit&.source_booking_id.present?
  end

  def reschedule_source_booking
    reschedule_credit&.source_booking
  end

  def pending_reschedule_replacement
    credit = RescheduleCredit.applied.find_by(source_booking_id: id)
    replacement = credit&.applied_booking
    replacement if replacement&.pending_payment?
  end

  def stored_reservation_mode
    pricing_breakdown&.dig('reservation_mode').presence
  end

  def reschedule_reservation_mode
    stored_reservation_mode || case booking_type
                             when 'jornada' then 'jornada'
                             when 'hourly' then 'bloque'
                             else 'hora'
                             end
  end

  def stored_slot_rate_id
    pricing_breakdown&.dig('slot_rate_id')
  end

  def reschedule_slot_rate
    if stored_slot_rate_id.present?
      space.slot_rates.find_by(id: stored_slot_rate_id)
    else
      infer_bloque_slot_rate
    end
  end

  def infer_bloque_slot_rate
    return unless space && start_at

    space.bloque_slot_rates.find do |rate|
      interval = space.schedule_interval_for_slot_rate(start_at.to_date, rate)
      interval && interval[:start_at] == start_at
    end
  end

  private

  def set_payment_expires_at
    return unless pending_payment? || status.nil?

    self.payment_expires_at ||= Time.current + self.class.payment_ttl
  end

  def set_duration_and_amount
    return unless start_at && end_at && space

    self.duration_minutes = ((end_at - start_at) / 60).to_i
    self.booking_type ||= :slot_based
    self.hours = (duration_minutes / 60.0).round if has_attribute?(:hours)
    apply_pricing
  end

  def apply_pricing
    return if spot_offer_id.present? && total_amount_cents.positive?

    result = PricingEngine.calculate(
      space,
      profesional,
      start_at,
      slot_count,
      end_at: end_at,
      booking_type: booking_type,
      jornada_definition: jornada_definition,
      slot_rate: reservation_slot_rate,
      rented_equipment_items: rented_equipment_items_for_pricing
    )

    self.total_amount_cents = result[:total_cents]
    self.discount_cents = result[:discount_cents]
    self.pricing_breakdown = {
      breakdown: result[:breakdown],
      subtotal_cents: result[:subtotal_cents],
      reservation_mode: reservation_mode.presence || inferred_reservation_mode_for_breakdown,
      slot_rate_id: reservation_slot_rate&.id,
      jornada_definition_id: jornada_definition&.id,
      rented_equipment_item_ids: rented_equipment_items_for_pricing.map(&:id)
    }
  end

  def inferred_reservation_mode_for_breakdown
    case booking_type
    when 'jornada' then 'jornada'
    when 'hourly' then 'bloque'
    else 'hora'
    end
  end

  def rented_equipment_items_for_pricing
    space.rented_equipment_items_from_params({ rented_equipment_item_ids: rented_equipment_item_ids }).to_a
  end

  def minimum_slots_met
    return unless slot_based?
    return unless space && duration_minutes.positive?

    slots = slot_count
    return if slots >= space.minimum_slots

    errors.add(:base, "mínimo #{space.minimum_slots} hora(s)")
  end

  def availability_check
    return unless space && start_at && end_at

    checker = AvailabilityChecker.new(space)
    unless checker.consecutive_slots_available?(start_at, slot_count)
      errors.add(:base, checker.error_message || 'Horario no disponible')
    end
  end

  def start_at_not_in_past
    return unless start_at

    errors.add(:base, 'El horario seleccionado ya pasó') if start_at < Time.current
  end

  def apply_reschedule_credit_deduction
    return unless reschedule_credit

    self.total_amount_cents = [total_amount_cents - reschedule_credit.amount_cents, 0].max
  end
end
