# frozen_string_literal: true

module Owner
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_owner!

    layout 'owner'

    private

    def require_owner!
      redirect_to root_path, alert: 'Acceso no autorizado' unless current_user&.owner? || current_user&.admin?
    end
  end
end
