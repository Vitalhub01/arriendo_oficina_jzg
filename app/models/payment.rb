# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :booking, optional: true
  belongs_to :membership, optional: true
  belongs_to :payer, class_name: 'User', inverse_of: :payments
  has_one :invoice, dependent: :destroy

  enum :status, { pending: 0, approved: 1, rejected: 2, refunded: 3 }
  enum :payment_kind, { booking: 0, membership: 1 }

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :booking_id, uniqueness: true, allow_nil: true

  def formatted_amount
    Money.new(amount_cents, 'CLP').format(no_cents_if_whole: true)
  end
end
