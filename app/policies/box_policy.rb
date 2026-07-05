# frozen_string_literal: true

class BoxPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.owner?
        scope.where(owner: user)
      elsif user&.admin?
        scope.all
      else
        scope.published_boxes
      end
    end
  end

  def index?
    true
  end

  def show?
    record.published? || owner_or_admin?
  end

  def create?
    user&.owner? || user&.admin?
  end

  def update?
    owner_or_admin?
  end

  def destroy?
    owner_or_admin?
  end

  private

  def owner_or_admin?
    user&.admin? || (user&.owner? && record.owner_id == user.id)
  end
end
