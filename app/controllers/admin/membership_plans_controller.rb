# frozen_string_literal: true

module Admin
  class MembershipPlansController < Admin::BaseController
    before_action :set_membership_plan, only: %i[show edit update destroy]

    def index
      @membership_plans = MembershipPlan.order(:name)
    end

    def show; end

    def new
      @membership_plan = MembershipPlan.new
    end

    def edit; end

    def create
      @membership_plan = MembershipPlan.new(membership_plan_params)

      if @membership_plan.save
        redirect_to admin_membership_plans_path, notice: 'Plan creado'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @membership_plan.update(membership_plan_params)
        redirect_to admin_membership_plan_path(@membership_plan), notice: 'Plan actualizado'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @membership_plan.destroy
      redirect_to admin_membership_plans_path, notice: 'Plan eliminado'
    end

    private

    def set_membership_plan
      @membership_plan = MembershipPlan.find(params.expect(:id))
    end

    def membership_plan_params
      params.expect(
        membership_plan: %i[name description benefits price_cents billing_period
                            discount_percent active]
      )
    end
  end
end
