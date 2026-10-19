# frozen_string_literal: true

module Users
  class ProfilesController < ApplicationController
    before_action :authenticate_user!

    def show
      redirect_to edit_profile_path
    end

    def edit
      @user = current_user
      @professional_profile = @user.professional_profile
    end

    def update
      @user = current_user
      @professional_profile = @user.professional_profile
      success = @user.update(profile_params)
      success &&= update_professional_profile if @professional_profile

      if success
        redirect_to edit_profile_path, notice: 'Perfil actualizado'
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def profile_params
      params.expect(user: [:name])
    end

    def update_professional_profile
      return true unless params[:professional_profile]

      if @professional_profile.update(professional_profile_params)
        @professional_profile.sync_onboarding_completed!
        true
      else
        false
      end
    end

    def professional_profile_params
      params.expect(professional_profile: %i[age gender profession interested_in_networking])
    end
  end
end
