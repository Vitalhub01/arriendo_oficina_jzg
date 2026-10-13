# frozen_string_literal: true

class ScheduleBlockOverride < ApplicationRecord
  belongs_to :schedule_block
  belongs_to :space, inverse_of: :schedule_block_overrides

  validates :date, presence: true
  validates :price_cents, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validate :blocked_or_price

  scope :for_week, lambda { |week_start|
    week_end = week_start + 6.days
    where(date: week_start..week_end)
  }

  private

  def blocked_or_price
    return if blocked?
    return if price_cents.present?

    errors.add(:base, 'indica bloqueo o un precio especial')
  end
end
