# frozen_string_literal: true

module Users
  class ProfilesController < ApplicationController
    before_action :authenticate_user!

    def show
      redirect_to edit_profile_path
    end

    def edit
      @user = current_user
    end

    def update
      @user = current_user
      if @user.update(profile_params)
        redirect_to edit_profile_path, notice: 'Perfil actualizado'
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def profile_params
      params.expect(user: [:name])
    end
  end
end
