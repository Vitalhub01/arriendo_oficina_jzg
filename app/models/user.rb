# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :trackable, :validatable

  enum :role, { admin: 0, profesional: 1, profesional_suscrito: 2 }

  has_one :professional_profile, dependent: :destroy
  has_many :bookings, foreign_key: :renter_id, dependent: :destroy, inverse_of: :profesional
  has_many :booking_series, foreign_key: :renter_id, dependent: :destroy, inverse_of: :renter
  has_many :payments, foreign_key: :payer_id, dependent: :destroy, inverse_of: :payer
  has_many :favorites, dependent: :destroy
  has_many :favorite_spaces, through: :favorites, source: :box, class_name: 'Space'
  has_many :testimonials, foreign_key: :profesional_id, dependent: :destroy, inverse_of: :profesional
  has_many :memberships, dependent: :destroy
  has_many :reschedule_credits, dependent: :destroy

  validates :name, presence: true

  def admin?
    role == 'admin'
  end

  def profesional?
    role == 'profesional'
  end

  def profesional_suscrito?
    role == 'profesional_suscrito'
  end

  def active_membership?
    memberships.current.exists?
  end

  def can_book?
    return true if admin?

    professional_profile&.verified? && professional_profile&.onboarding_completed?
  end
end
