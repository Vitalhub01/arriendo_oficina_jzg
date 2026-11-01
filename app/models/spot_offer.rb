# frozen_string_literal: true

class SpotOffer < ApplicationRecord
  include SpotOfferRecurrence

  belongs_to :space, class_name: 'Space', inverse_of: :spot_offers
  belongs_to :created_by, class_name: 'User'
  belongs_to :profesional, class_name: 'User', optional: true

  has_many :bookings, dependent: :destroy
  has_one :payment, dependent: :destroy

  enum :status, { active: 0, paid: 1, cancelled: 2 }

  validates :token, presence: true, uniqueness: true
  validates :total_price_cents, numericality: { greater_than: 0, only_integer: true }
  validates :starts_on, :ends_on, :daily_start_time, :daily_end_time, presence: true
  validate :ends_on_after_starts_on
  validate :daily_end_after_start
  validate :weekdays_selection

  before_validation :normalize_weekdays_list
  before_validation :generate_token, on: :create

  scope :recent, -> { order(created_at: :desc) }
  scope :with_reservations, -> { joins(:bookings).distinct }

  def to_param
    token
  end

  def shareable_path
    Rails.application.routes.url_helpers.spot_offer_path(token)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, 'debe ser igual o posterior al inicio') if ends_on < starts_on
  end

  def daily_end_after_start
    return if daily_start_time.blank? || daily_end_time.blank?

    errors.add(:daily_end_time, 'debe ser posterior al inicio') if daily_end_time <= daily_start_time
  end

  def normalize_weekdays_list
    return if weekdays.blank?

    self.weekdays = Array(weekdays).map(&:to_i).uniq.sort.intersection(SpotOfferRecurrence::ALL_WEEKDAYS)
  end

  def weekdays_selection
    list = Array(weekdays).map(&:to_i).uniq.intersection(SpotOfferRecurrence::ALL_WEEKDAYS)
    return if list.any?

    errors.add(:weekdays, 'elige al menos un día de la semana')
  end
end
