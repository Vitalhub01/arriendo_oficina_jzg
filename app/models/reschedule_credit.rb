# frozen_string_literal: true

class RescheduleCredit < ApplicationRecord
  belongs_to :user
  belongs_to :source_booking, class_name: 'Booking'
  belongs_to :applied_booking, class_name: 'Booking', optional: true

  enum :status, { available: 0, applied: 1, expired: 2 }

  validates :amount_cents, :hours, presence: true
  validates :amount_cents, :hours, numericality: { greater_than: 0, only_integer: true }

  scope :usable, -> { available.where('expires_at IS NULL OR expires_at > ?', Time.current) }

  def past_expiration?
    expires_at.present? && expires_at <= Time.current
  end
end
