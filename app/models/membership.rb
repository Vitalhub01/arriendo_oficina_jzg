# frozen_string_literal: true

class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :membership_plan

  enum :status, { active: 0, expired: 1, cancelled: 2 }

  validates :starts_at, :expires_at, presence: true
  validate :expires_after_start

  scope :current, lambda {
    active.where(starts_at: ..Time.current, expires_at: Time.current...)
  }

  def current?
    active? && starts_at <= Time.current && expires_at > Time.current
  end

  private

  def expires_after_start
    return if starts_at.blank? || expires_at.blank?

    errors.add(:expires_at, 'debe ser posterior al inicio') if expires_at <= starts_at
  end
end
