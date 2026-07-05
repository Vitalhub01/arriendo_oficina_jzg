# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  after_action :track_ga_flash_event

  private

  def track_ga_flash_event
    return unless flash[:ga_event]

    event = flash[:ga_event]
    flash[:ga_event_script] = helpers.ga_event_script(event[:name], event[:params] || {})
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[name rut])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end

  def user_not_authorized
    redirect_to root_path, alert: 'No tienes permiso para realizar esta acción'
  end
end
