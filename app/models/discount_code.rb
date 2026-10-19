# frozen_string_literal: true

class DiscountCode < ApplicationRecord
  has_many :bookings, dependent: :nullify

  enum :discount_type, { percent: 0, fixed_amount: 1 }

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :starts_at, :ends_at, presence: true
  validates :percent, numericality: { only_integer: true, in: 1..100 }, if: :percent?
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }, if: :fixed_amount?
  validate :ends_after_starts
  validate :discount_value_present
  validate :at_least_one_booking_type

  before_validation :normalize_code

  scope :active, -> { where(active: true) }

  def self.find_by_normalized(code)
    normalized = normalize_code(code)
    return if normalized.blank?

    find_by('lower(code) = ?', normalized.downcase)
  end

  def self.normalize_code(raw)
    raw.to_s.strip.upcase.gsub(/\s+/, '')
  end

  def redeemable_at?(time = Time.current)
    active? && time >= starts_at && time <= ends_at && within_use_limit?
  end

  def within_use_limit?
    return true if max_uses.blank?

    redemptions_count < max_uses
  end

  def discount_cents_for(payable_cents)
    payable = payable_cents.to_i
    return 0 if payable <= 0

    if percent?
      (payable * percent / 100.0).round
    else
      [amount_cents.to_i, payable].min
    end
  end

  def reserve_redemption!
    with_lock do
      raise ActiveRecord::RecordInvalid, self unless redeemable_at?

      increment!(:redemptions_count)
    end
  end

  def release_redemption!
    with_lock do
      return if redemptions_count <= 0

      decrement!(:redemptions_count)
    end
  end

  def display_discount
    if percent?
      "#{percent}%"
    else
      Money.new(amount_cents, 'CLP').format(no_cents_if_whole: true)
    end
  end

  def applies_to_booking?(booking)
    applies_to_booking_type?(booking.booking_type)
  end

  def applies_to_booking_type?(booking_type)
    case booking_type.to_s
    when 'hourly'
      applies_to_hourly?
    when 'slot_based'
      applies_to_slot_based?
    when 'jornada'
      applies_to_jornada?
    else
      false
    end
  end

  def display_booking_types
    labels = []
    labels << 'Hora' if applies_to_hourly?
    labels << 'Bloque' if applies_to_slot_based?
    labels << 'Jornada' if applies_to_jornada?
    labels.join(', ')
  end

  private

  def normalize_code
    self.code = self.class.normalize_code(code)
  end

  def ends_after_starts
    return unless starts_at && ends_at

    errors.add(:ends_at, 'debe ser posterior al inicio') if ends_at <= starts_at
  end

  def discount_value_present
    if percent? && percent.blank?
      errors.add(:percent, :blank)
    elsif fixed_amount? && amount_cents.blank?
      errors.add(:amount_cents, :blank)
    end
  end

  def at_least_one_booking_type
    return if applies_to_hourly? || applies_to_slot_based? || applies_to_jornada?

    errors.add(:base, 'Selecciona al menos un tipo de reserva')
  end
end
