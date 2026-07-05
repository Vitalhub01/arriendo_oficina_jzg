# frozen_string_literal: true

class ProfessionalProfile < ApplicationRecord
  belongs_to :user

  enum :validation_status, {
    pending: 0,
    auto_verified: 1,
    manual_verified: 2,
    rejected: 3
  }

  validates :rut, presence: true, uniqueness: true
  validate :rut_must_be_valid

  def verified?
    auto_verified? || manual_verified?
  end

  def full_rut
    return if rut.blank?

    RutValidator.format(rut)
  end

  private

  def rut_must_be_valid
    return if rut.blank?

    errors.add(:rut, 'inválido') unless RutValidator.valid?(rut)
  end
end
