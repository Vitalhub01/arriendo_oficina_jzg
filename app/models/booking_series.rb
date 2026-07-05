# frozen_string_literal: true

class BookingSeries < ApplicationRecord
  belongs_to :box
  belongs_to :renter, class_name: 'User', inverse_of: :booking_series
  has_many :bookings, dependent: :nullify

  enum :status, { active: 0, paused: 1, cancelled: 2 }

  validates :day_of_week, inclusion: { in: 0..6 }
  validates :start_time, :end_time, :starts_on, :ends_on, presence: true
  validate :end_after_start
  validate :ends_on_after_starts_on

  def hours
    ((end_time - start_time) / 1.hour).round
  end

  def occurrences(limit: 52)
    dates = []
    date = starts_on
    while date <= ends_on && dates.size < limit
      dates << date if date.wday == day_of_week_to_ruby_wday
      date += 1.day
    end
    dates
  end

  private

  def day_of_week_to_ruby_wday
    # 0=Monday in our schema, Ruby wday: 0=Sunday
    day_of_week == 6 ? 0 : day_of_week + 1
  end

  def end_after_start
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, 'debe ser posterior al inicio') if end_time <= start_time
  end

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, 'debe ser posterior o igual al inicio') if ends_on < starts_on
  end
end
