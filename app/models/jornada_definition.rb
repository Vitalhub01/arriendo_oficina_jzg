# frozen_string_literal: true

class JornadaDefinition < ApplicationRecord
  belongs_to :space, optional: true, class_name: 'Space', inverse_of: :jornada_definitions
  belongs_to :office, optional: true, inverse_of: :jornada_definitions

  validates :name, :start_time, :end_time, :price_cents, presence: true
  validates :price_cents, numericality: { greater_than: 0, only_integer: true }
  validate :end_after_start

  scope :active, -> { where(active: true) }

  def duration_hours
    return 0 if start_time.blank? || end_time.blank?

    ((end_time - start_time) / 1.hour).round
  end

  def formatted_price
    Money.new(price_cents, 'CLP').format(no_cents_if_whole: true)
  end

  private

  def end_after_start
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, 'debe ser posterior al inicio') if end_time <= start_time
  end
end
