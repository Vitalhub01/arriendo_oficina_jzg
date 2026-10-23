# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :booking, optional: true
  belongs_to :membership, optional: true
  belongs_to :spot_offer, optional: true
  belongs_to :payer, class_name: 'User', inverse_of: :payments
  has_one :invoice, dependent: :destroy

  enum :status, { pending: 0, approved: 1, rejected: 2, refunded: 3 }
  enum :payment_kind, { booking: 0, membership: 1, spot_offer: 2 }

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :booking_id, uniqueness: true, allow_nil: true
  validates :spot_offer_id, uniqueness: true, allow_nil: true
  validate :single_payable_target

  def single_payable_target
    targets = [booking_id, membership_id, spot_offer_id].compact
    return if targets.size == 1

    errors.add(:base, 'El pago debe asociarse a una sola reserva, membresía u oferta spot')
  end

  def formatted_amount
    Money.new(amount_cents, 'CLP').format(no_cents_if_whole: true)
  end
end
