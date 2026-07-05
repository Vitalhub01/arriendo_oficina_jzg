# frozen_string_literal: true

module Admin
  class PricingRulesController < Admin::BaseController
    before_action :set_pricing_rule, only: %i[show edit update destroy]

    def index
      @pricing_rules = PricingRule.order(priority: :desc, created_at: :desc)
    end

    def show; end

    def new
      @pricing_rule = PricingRule.new
    end

    def edit; end

    def create
      @pricing_rule = PricingRule.new(pricing_rule_params)

      if @pricing_rule.save
        redirect_to admin_pricing_rules_path, notice: 'Regla de precio creada'
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @pricing_rule.update(pricing_rule_params)
        redirect_to admin_pricing_rule_path(@pricing_rule), notice: 'Regla de precio actualizada'
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @pricing_rule.destroy
      redirect_to admin_pricing_rules_path, notice: 'Regla de precio eliminada'
    end

    private

    def set_pricing_rule
      @pricing_rule = PricingRule.find(params.expect(:id))
    end

    def pricing_rule_params
      params.expect(
        pricing_rule: [:name, :rule_type, :active, :stackable, :priority, { config: {} }]
      )
    end
  end
end
