# frozen_string_literal: true

class SlotRate < ApplicationRecord
  belongs_to :space, inverse_of: :slot_rates

  validates :name, :start_time, :end_time, :price_per_slot_cents, presence: true
  validates :price_per_slot_cents, numericality: { greater_than: 0, only_integer: true }
  validates :block_price_cents, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validate :end_after_start

  def block_price_cents_effective
    block_price_cents.presence || price_per_slot_cents
  end

  scope :ordered, -> { order(:position, :start_time) }
  scope :for_bloque_reservation, lambda {
    where(name: SpaceBlockPeriods::PERIODS.map { |period| period[:name] })
  }

  def formatted_price
    Money.new(price_per_slot_cents, 'CLP').format(no_cents_if_whole: true)
  end

  def covers_time?(time)
    time_seconds = time.seconds_since_midnight
    start_seconds = start_time.seconds_since_midnight
    end_seconds = end_time.seconds_since_midnight

    time_seconds >= start_seconds && time_seconds < end_seconds
  end

  private

  def end_after_start
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, 'debe ser posterior al inicio') if end_time <= start_time
  end
end
