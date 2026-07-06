# frozen_string_literal: true

class Booking < ApplicationRecord
  include OverlapCheckable

  belongs_to :space, class_name: 'Space', foreign_key: :box_id, inverse_of: :bookings
  belongs_to :profesional, class_name: 'User', foreign_key: :renter_id, inverse_of: :bookings
  belongs_to :booking_series, optional: true
  belongs_to :jornada_definition, optional: true
  belongs_to :reschedule_credit, optional: true
  has_one :payment, dependent: :destroy
  has_one :testimonial, dependent: :destroy

  enum :status, { pending_payment: 0, confirmed: 1, cancelled: 2, completed: 3, rescheduled: 4 }
  enum :booking_type, { hourly: 0, jornada: 1, slot_based: 2 }

  validates :start_at, :end_at, :duration_minutes, presence: true
  validates :duration_minutes, numericality: { greater_than: 0, only_integer: true }
  validates :total_amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :minimum_slots_met, on: :create
  validate :availability_check, on: :create

  before_validation :set_payment_expires_at, on: :create
  before_validation :set_duration_and_amount, on: :create
  before_validation :apply_reschedule_credit_deduction, on: :create

  scope :upcoming, -> { where(start_at: Time.current..).order(:start_at) }
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

  def slot_count
    return 0 unless space && duration_minutes.to_i.positive?

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

  private

  def set_payment_expires_at
    return unless pending_payment? || status.nil?

    self.payment_expires_at ||= Time.current + self.class.payment_ttl
  end

  def set_duration_and_amount
    return unless start_at && end_at && space

    self.duration_minutes = ((end_at - start_at) / 60).to_i
    self.booking_type = :slot_based
    self.hours = (duration_minutes / 60.0).round if has_attribute?(:hours)
    apply_pricing
  end

  def apply_pricing
    result = PricingEngine.calculate(
      space,
      profesional,
      start_at,
      slot_count
    )

    self.total_amount_cents = result[:total_cents]
    self.discount_cents = result[:discount_cents]
    self.pricing_breakdown = { breakdown: result[:breakdown], subtotal_cents: result[:subtotal_cents] }
  end

  def minimum_slots_met
    return unless space && duration_minutes.positive?

    slots = slot_count
    return if slots >= space.minimum_slots

    errors.add(:base, "mínimo #{space.minimum_slots} bloque(s)")
  end

  def availability_check
    return unless space && start_at && end_at

    checker = AvailabilityChecker.new(space)
    unless checker.consecutive_slots_available?(start_at, slot_count)
      errors.add(:base, checker.error_message || 'Horario no disponible')
    end
  end

  def apply_reschedule_credit_deduction
    return unless reschedule_credit

    self.total_amount_cents = [total_amount_cents - reschedule_credit.amount_cents, 0].max
  end
end
