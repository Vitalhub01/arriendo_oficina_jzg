# frozen_string_literal: true

class ScheduleBlock < ApplicationRecord
  belongs_to :space, inverse_of: :schedule_blocks
  has_many :overrides, class_name: 'ScheduleBlockOverride', dependent: :destroy, inverse_of: :schedule_block

  validates :day_of_week, :start_time, :end_time, :price_cents, presence: true
  validates :price_cents, numericality: { greater_than: 0, only_integer: true }
  validates :day_of_week, inclusion: { in: 0..6 }
  validate :end_after_start
  validate :no_overlap_on_same_day

  scope :for_day, ->(day) { where(day_of_week: day) }
  scope :ordered, -> { order(:position, :start_time) }

  def duration_minutes
    ((end_time - start_time) / 60).to_i
  end

  def formatted_price
    Money.new(price_cents, 'CLP').format(no_cents_if_whole: true)
  end

  def override_for(date)
    overrides.find_by(date: date.to_date)
  end

  def blocked_on?(date)
    override_for(date)&.blocked?
  end

  def price_cents_on(date)
    override = override_for(date)
    return price_cents unless override&.price_cents.present?

    override.price_cents
  end

  def formatted_price_on(date)
    Money.new(price_cents_on(date), 'CLP').format(no_cents_if_whole: true)
  end

  def start_time_on(date)
    override_for(date)&.start_time.presence || start_time
  end

  def end_time_on(date)
    override_for(date)&.end_time.presence || end_time
  end

  def starts_at_on(date)
    t = start_time_on(date)
    Time.zone.local(date.year, date.month, date.day, t.hour, t.min, t.sec)
  end

  def ends_at_on(date)
    t = end_time_on(date)
    Time.zone.local(date.year, date.month, date.day, t.hour, t.min, t.sec)
  end

  def overlaps?(other)
    day_of_week == other.day_of_week &&
      start_time < other.end_time &&
      end_time > other.start_time
  end

  private

  def end_after_start
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, 'debe ser posterior al inicio') if end_time <= start_time
  end

  def no_overlap_on_same_day
    return if space_id.blank? || start_time.blank? || end_time.blank?

    overlapping = space.schedule_blocks
                       .for_day(day_of_week)
                       .where.not(id: id)
                       .where('start_time < ? AND end_time > ?', end_time, start_time)

    errors.add(:base, 'se solapa con otro bloque del mismo día') if overlapping.exists?
  end
end
