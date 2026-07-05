# frozen_string_literal: true

class AvailabilityRule < ApplicationRecord
  belongs_to :space, class_name: 'Space', foreign_key: :box_id, inverse_of: :availability_rules, optional: true
  alias box space

  validates :day_of_week, inclusion: { in: 0..6 }
  validates :start_time, :end_time, presence: true
  validate :end_after_start

  DAY_NAMES = %w[Lunes Martes Miércoles Jueves Viernes Sábado Domingo].freeze

  scope :for_day, ->(day) { where(day_of_week: day) }
  scope :active_on, lambda { |date|
    where('(valid_from IS NULL OR valid_from <= ?) AND (valid_until IS NULL OR valid_until >= ?)', date, date)
  }

  def day_name
    DAY_NAMES[day_of_week]
  end

  private

  def end_after_start
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, 'debe ser posterior al inicio') if end_time <= start_time
  end
end
