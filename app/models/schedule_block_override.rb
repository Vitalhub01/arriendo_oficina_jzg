# frozen_string_literal: true

class ScheduleBlockOverride < ApplicationRecord
  belongs_to :schedule_block
  belongs_to :space, inverse_of: :schedule_block_overrides

  validates :date, presence: true
  validates :price_cents, numericality: { greater_than: 0, only_integer: true }, allow_nil: true
  validate :blocked_or_customization
  validate :times_complete_and_ordered, unless: :blocked?

  scope :for_week, lambda { |week_start|
    week_end = week_start + 6.days
    where(date: week_start..week_end)
  }

  private

  def blocked_or_customization
    return if blocked?
    return if price_cents.present?
    return if start_time.present? && end_time.present?

    errors.add(:base, 'indica bloqueo, precio especial o horario para este día')
  end

  def times_complete_and_ordered
    start_present = start_time.present?
    end_present = end_time.present?
    return unless start_present || end_present

    if start_present ^ end_present
      errors.add(:base, 'indica hora de inicio y fin para este día')
      return
    end

    errors.add(:end_time, 'debe ser posterior al inicio') if end_time <= start_time
  end
end
