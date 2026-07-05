# frozen_string_literal: true

module Admin
  class MembershipsController < Admin::BaseController
    def index
      scope = Membership.includes(:user, :membership_plan).order(created_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?
      @pagy, @memberships = pagy(scope)
    end
  end
end
