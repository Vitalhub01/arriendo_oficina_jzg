# frozen_string_literal: true

module OverlapCheckable
  extend ActiveSupport::Concern

  included do
    validate :no_overlapping_bookings, on: :create
  end

  private

  def no_overlapping_bookings
    return if box.blank? || start_at.blank? || end_at.blank?

    overlapping = box.bookings
                     .blocking_availability
                     .where('start_at < ? AND end_at > ?', end_at, start_at)

    overlapping = overlapping.where.not(id: id) if persisted?

    errors.add(:base, 'El horario seleccionado ya no está disponible') if overlapping.exists?
  end
end
