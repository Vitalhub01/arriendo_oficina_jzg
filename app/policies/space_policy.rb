# frozen_string_literal: true

class SpacePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        scope.published_spaces
      end
    end
  end

  def index?
    true
  end

  def show?
    record.published? || user&.admin?
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end
end
