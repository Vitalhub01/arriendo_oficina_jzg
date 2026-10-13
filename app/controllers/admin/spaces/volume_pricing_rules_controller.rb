# frozen_string_literal: true

module Admin
  module Spaces
    class VolumePricingRulesController < Admin::BaseController
      before_action :set_space
      before_action :set_rule, only: %i[update destroy]

      def create
        @rule = @space.pricing_rules.build(volume_rule_params.merge(rule_type: :volume_discount))

        if @rule.save
          redirect_to admin_space_schedule_blocks_path(@space), notice: 'Descuento por volumen guardado'
        else
          redirect_to admin_space_schedule_blocks_path(@space), alert: @rule.errors.full_messages.to_sentence
        end
      end

      def update
        if @rule.update(volume_rule_params)
          redirect_to admin_space_schedule_blocks_path(@space), notice: 'Descuento por volumen actualizado'
        else
          redirect_to admin_space_schedule_blocks_path(@space), alert: @rule.errors.full_messages.to_sentence
        end
      end

      def destroy
        @rule.destroy
        redirect_to admin_space_schedule_blocks_path(@space), notice: 'Descuento eliminado'
      end

      private

      def set_space
        @space = Space.find(params.expect(:space_id))
      end

      def set_rule
        @rule = @space.pricing_rules.volume_discount.find(params.expect(:id))
      end

      def volume_rule_params
        raw = params.expect(pricing_rule: [:name, :active, :priority, { config: {} }])
        raw.to_h
      end
    end
  end
end
