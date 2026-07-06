# frozen_string_literal: true

module Admin
  module Spaces
    class AvailabilitiesController < Admin::BaseController
      before_action :set_space

      def show; end

      private

      def set_space
        @space = Space.find(params.expect(:space_id))
      end
    end
  end
end
