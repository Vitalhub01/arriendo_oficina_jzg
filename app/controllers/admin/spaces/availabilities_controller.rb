# frozen_string_literal: true

module Admin
  module Spaces
    class AvailabilitiesController < Admin::BaseController
      before_action :set_space

      def show
        redirect_to admin_space_schedule_blocks_path(@space)
      end

      private

      def set_space
        @space = Space.find(params.expect(:space_id))
      end
    end
  end
end
