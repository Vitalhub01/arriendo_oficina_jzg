# frozen_string_literal: true

module Admin
  class PasswordResetRequestsController < Admin::BaseController
    before_action :set_request, only: %i[update]

    def index
      scope = PasswordResetRequest.includes(:user, :resolved_by).pending_first
      scope = scope.where(status: params[:status]) if params[:status].present?
      @pagy, @password_reset_requests = pagy(scope)
      @pending_count = PasswordResetRequest.pending.count
    end

    def update
      if params[:resolve]
        @password_reset_request.resolve!(by: current_user)
        redirect_to admin_password_reset_requests_path, notice: 'Solicitud marcada como atendida'
      else
        redirect_to admin_password_reset_requests_path, alert: 'Acción no válida'
      end
    end

    private

    def set_request
      @password_reset_request = PasswordResetRequest.find(params.expect(:id))
    end
  end
end
