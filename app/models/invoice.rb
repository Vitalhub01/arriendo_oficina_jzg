# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :payment
  belongs_to :user

  has_one_attached :pdf

  enum :status, { pending: 0, issued: 1, failed: 2 }

  validates :provider, presence: true
  validates :payment_id, uniqueness: true

  def pdf_filename
    "boleta_#{folio}.pdf"
  end

  def downloadable?
    issued? && pdf.attached?
  end
end
