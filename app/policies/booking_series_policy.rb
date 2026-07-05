# frozen_string_literal: true

class BookingSeriesPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user&.owner?
        scope.where(box_id: user.boxes.select(:id)).or(scope.where(renter: user))
      elsif user
        scope.where(renter: user)
      else
        scope.none
      end
    end
  end

  def index?
    user.present?
  end

  def show?
    user&.admin? || record.renter_id == user&.id || record.box.owner_id == user&.id
  end

  def update?
    user&.admin? || record.renter_id == user&.id
  end
end
