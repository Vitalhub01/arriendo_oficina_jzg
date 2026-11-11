# frozen_string_literal: true

module Users
  class PasswordsController < Devise::PasswordsController
    layout 'application'

    def create
      email = resource_params[:email]
      Users::CreatePasswordResetRequest.new(email: email).call

      redirect_to password_request_sent_path
    end

    def sent; end
  end
end
