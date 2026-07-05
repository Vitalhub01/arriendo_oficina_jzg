# frozen_string_literal: true

class OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_professional_profile

  def show
    redirect_to root_path if @professional_profile.onboarding_completed?
  end

  def update
    if @professional_profile.update(onboarding_params.merge(onboarding_completed: true))
      redirect_to root_path, notice: 'Perfil completado. Ya puedes reservar espacios.'
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
    params.expect(professional_profile: %i[age gender interested_in_networking])
  end
end
