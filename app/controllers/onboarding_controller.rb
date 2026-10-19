# frozen_string_literal: true

class OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_professional_profile

  def show
    redirect_to edit_profile_path if @professional_profile.profile_complete?
  end

  def update
    if @professional_profile.update(onboarding_params)
      @professional_profile.sync_onboarding_completed!
      redirect_to root_path, notice: profile_saved_notice
    else
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_professional_profile
    @professional_profile = current_user.professional_profile
    redirect_to root_path, alert: 'Debes registrarte como profesional' unless @professional_profile
  end

  def onboarding_params
    params.expect(professional_profile: %i[age gender profession interested_in_networking])
  end

  def profile_saved_notice
    if @professional_profile.profile_complete?
      'Perfil completado. ¡Gracias!'
    else
      'Información guardada. Aún faltan datos por completar.'
    end
  end
end
