# frozen_string_literal: true

module Admin
  module Spaces
    class AvailabilityRulesController < Admin::BaseController
      before_action :set_space

      def index
        @rules = @space.availability_rules.order(:day_of_week, :start_time)
        @rule = @space.availability_rules.build
      end

      def create
        @rule = @space.availability_rules.build(rule_params)
        if @rule.save
          redirect_to admin_space_availability_rules_path(@space), notice: 'Horario agregado'
        else
          @rules = @space.availability_rules.order(:day_of_week, :start_time)
          render :index, status: :unprocessable_content
        end
      end

      def destroy
        @space.availability_rules.find(params.expect(:id)).destroy
        redirect_to admin_space_availability_rules_path(@space), notice: 'Horario eliminado'
      end

      private

      def set_space
        @space = Space.find(params.expect(:space_id))
      end

      def rule_params
        params.expect(availability_rule: %i[day_of_week start_time end_time valid_from valid_until])
      end
    end
  end
end
