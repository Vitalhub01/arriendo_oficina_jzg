# frozen_string_literal: true

class Testimonial < ApplicationRecord
  belongs_to :space, class_name: 'Space', foreign_key: :box_id, inverse_of: :testimonials, optional: true
  belongs_to :profesional, class_name: 'User', inverse_of: :testimonials, optional: true
  belongs_to :booking, optional: true

  validates :body, presence: true
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true
  validates :booking_id, uniqueness: true, allow_nil: true
  validate :booking_must_be_completed, if: :booking_id?
  validate :author_present
  validate :only_one_general_per_professional, if: -> { booking_id.nil? && profesional_id.present? }

  scope :visible, -> { where(visible: true) }
  scope :general, -> { where(booking_id: nil) }

  def display_author
    author_name.presence || profesional&.name
  end

  private

  def author_present
    return if display_author.present?

    errors.add(:author_name, 'indica un nombre o asocia un profesional')
  end

  def booking_must_be_completed
    return if booking&.completed?

    errors.add(:booking, 'debe estar completada para dejar testimonio')
  end

  def only_one_general_per_professional
    scope = Testimonial.general.where(profesional_id: profesional_id)
    scope = scope.where.not(id: id) if persisted?
    return unless scope.exists?

    errors.add(:base, 'Ya enviaste un comentario')
  end
end
