# frozen_string_literal: true

module Admin
  module Spaces
    class SlotRatesController < Admin::BaseController
      before_action :set_space
      before_action :set_slot_rate, only: %i[edit update destroy]

      def index
        @slot_rates = @space.slot_rates.ordered
        @slot_rate = @space.slot_rates.build
      end

      def new
        @slot_rate = @space.slot_rates.build
      end

      def edit; end

      def create
        @slot_rate = @space.slot_rates.build(slot_rate_params)

        if @slot_rate.save
          redirect_to admin_space_slot_rates_path(@space), notice: 'Tarifa creada'
        else
          @slot_rates = @space.slot_rates.ordered
          render :index, status: :unprocessable_content
        end
      end

      def update
        if @slot_rate.update(slot_rate_params)
          redirect_to admin_space_slot_rates_path(@space), notice: 'Tarifa actualizada'
        else
          render :edit, status: :unprocessable_content
        end
      end

      def destroy
        @slot_rate.destroy
        redirect_to admin_space_slot_rates_path(@space), notice: 'Tarifa eliminada'
      end

      private

      def set_space
        @space = Space.find(params.expect(:space_id))
      end

      def set_slot_rate
        @slot_rate = @space.slot_rates.find(params.expect(:id))
      end

      def slot_rate_params
        params.expect(slot_rate: %i[name start_time end_time price_per_slot_cents position])
      end
    end
  end
end
