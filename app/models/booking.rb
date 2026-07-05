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
  enum :booking_type, { hourly: 0, jornada: 1 }

  validates :start_at, :end_at, :hours, presence: true
  validates :hours, numericality: { greater_than: 0, only_integer: true }
  validates :total_amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :minimum_hours_met, if: :hourly?
  validate :jornada_definition_present, if: :jornada?
  validate :availability_check, on: :create

  before_validation :set_payment_expires_at, on: :create
  before_validation :set_hours_and_amount, on: :create
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

  def box
    space
  end

  private

  def set_payment_expires_at
    return unless pending_payment? || status.nil?

    self.payment_expires_at ||= Time.current + self.class.payment_ttl
  end

  def set_hours_and_amount
    return unless start_at && end_at && space

    self.hours = calculate_hours
    apply_pricing
  end

  def calculate_hours
    if jornada? && jornada_definition
      jornada_definition.duration_hours
    else
      ((end_at - start_at) / 1.hour).round
    end
  end

  def apply_pricing
    result = PricingEngine.calculate(
      space,
      profesional,
      booking_type,
      hours,
      jornada_definition
    )

    self.total_amount_cents = result[:total_cents]
    self.discount_cents = result[:discount_cents]
    self.pricing_breakdown = { breakdown: result[:breakdown], subtotal_cents: result[:subtotal_cents] }
  end

  def minimum_hours_met
    return unless space && hours

    errors.add(:hours, "mínimo #{space.minimum_hours} hora(s)") if hours < space.minimum_hours
  end

  def jornada_definition_present
    errors.add(:jornada_definition, 'es requerida para reservas por jornada') if jornada_definition.blank?
  end

  def availability_check
    return unless space && start_at && end_at

    checker = AvailabilityChecker.new(space)
    return if checker.available?(start_at, end_at)

    errors.add(:base, checker.error_message || 'Horario no disponible')
  end

  def apply_reschedule_credit_deduction
    return unless reschedule_credit

    self.total_amount_cents = [total_amount_cents - reschedule_credit.amount_cents, 0].max
  end
end
