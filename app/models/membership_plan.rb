# frozen_string_literal: true

class MembershipPlan < ApplicationRecord
  has_many :memberships, dependent: :restrict_with_error

  enum :billing_period, { monthly: 0, quarterly: 1, annual: 2 }

  validates :name, :price_cents, presence: true
  validates :price_cents, :discount_percent, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :active, -> { where(active: true) }

  def formatted_price
    Money.new(price_cents, 'CLP').format(no_cents_if_whole: true)
  end
end
