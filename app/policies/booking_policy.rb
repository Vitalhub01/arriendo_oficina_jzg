# frozen_string_literal: true

class BookingPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user
        scope.where(renter_id: user.id)
      else
        scope.none
      end
    end
  end

  def index?
    user.present?
  end

  def show?
    user&.admin? || record.profesional_id == user&.id
  end

  def create?
    user&.profesional? || user&.profesional_suscrito? || user&.admin?
  end

  def checkout?
    (user&.admin? || record.profesional_id == user&.id) && record.pending_payment? && !record.payment_expired?
  end

  def cancel?
    Bookings::Cancel.new(booking: record, actor: user).cancellable?
  end

  def reschedule?
    Bookings::Reschedule.new(booking: record, actor: user, params: {}).rescheduleable?
  end
end
