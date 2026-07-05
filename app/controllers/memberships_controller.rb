# frozen_string_literal: true

class MembershipsController < ApplicationController
  before_action :authenticate_user!

  def show
    @membership = current_user.memberships.current.first
    @membership_plans = MembershipPlan.active.order(:price_cents)
  end

  def create
    plan = MembershipPlan.active.find(params.expect(:membership_plan_id))

    result = Payments::MercadoPago::CreateMembershipPreference.new(
      user: current_user,
      membership_plan: plan
    ).call

    if result.success? && result.init_point.present?
      flash[:ga_event] = { name: 'membership_purchased', params: { plan_id: plan.id } }
      redirect_to result.init_point, allow_other_host: true
    else
      redirect_to membership_path, alert: result.error || 'No se pudo iniciar el pago de membresía.'
    end
  end
end
