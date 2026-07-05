# frozen_string_literal: true

class Testimonial < ApplicationRecord
  belongs_to :space, class_name: 'Space', foreign_key: :box_id, inverse_of: :testimonials
  belongs_to :profesional, class_name: 'User', inverse_of: :testimonials
  belongs_to :booking

  validates :rating, inclusion: { in: 1..5 }, allow_nil: true
  validates :booking_id, uniqueness: true
  validate :booking_must_be_completed

  scope :visible, -> { where(visible: true) }

  private

  def booking_must_be_completed
    return if booking&.completed?

    errors.add(:booking, 'debe estar completada para dejar testimonio')
  end
end
