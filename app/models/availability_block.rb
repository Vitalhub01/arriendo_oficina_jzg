# frozen_string_literal: true

class AvailabilityBlock < ApplicationRecord
  belongs_to :space, class_name: 'Space', foreign_key: :box_id, inverse_of: :availability_blocks, optional: true
  alias box space

  validates :start_at, :end_at, presence: true
  validate :end_after_start

  private

  def end_after_start
    return if start_at.blank? || end_at.blank?

    errors.add(:end_at, 'debe ser posterior al inicio') if end_at <= start_at
  end
end
