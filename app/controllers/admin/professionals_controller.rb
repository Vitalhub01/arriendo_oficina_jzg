# frozen_string_literal: true

module Admin
  class ProfessionalsController < Admin::BaseController
    before_action :set_professional, only: %i[show update]

    def index
      scope = ProfessionalProfile.includes(:user).order(created_at: :desc)
      scope = scope.where(validation_status: params[:validation_status]) if params[:validation_status].present?
      @pagy, @professional_profiles = pagy(scope)
    end

    def show; end

    def update
      if params[:approve].present?
        @professional_profile.update!(
          validation_status: :manual_verified,
          rejection_reason: nil
        )
        redirect_to admin_professional_path(@professional_profile), notice: 'Profesional verificado'
      elsif params[:reject].present?
        @professional_profile.update!(
          validation_status: :rejected,
          rejection_reason: professional_params[:rejection_reason]
        )
        redirect_to admin_professional_path(@professional_profile), notice: 'Profesional rechazado'
      else
        if @professional_profile.update(professional_params)
          redirect_to admin_professional_path(@professional_profile), notice: 'Perfil actualizado'
        else
          render :show, status: :unprocessable_content
        end
      end
    end

    private

    def set_professional
      @professional_profile = ProfessionalProfile.find(params.expect(:id))
    end

    def professional_params
      params.expect(professional_profile: %i[validation_status rejection_reason rut])
    end
  end
end
