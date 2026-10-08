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
      if params.key?(:approve)
        @professional_profile.assign_attributes(
          validation_status: :manual_verified,
          rejection_reason: nil
        )
        @professional_profile.save!(validate: false)
        redirect_to admin_professional_path(@professional_profile), notice: 'Profesional verificado'
      elsif params.key?(:reject)
        @professional_profile.assign_attributes(
          validation_status: :rejected,
          rejection_reason: professional_params[:rejection_reason]
        )
        @professional_profile.save!(validate: false)
        redirect_to admin_professional_path(@professional_profile), notice: 'Profesional rechazado'
      elsif params.key?(:ban)
        @professional_profile.user.update!(banned_at: Time.current)
        redirect_to admin_professional_path(@professional_profile), notice: 'Acceso suspendido'
      elsif params.key?(:unban)
        @professional_profile.user.update!(banned_at: nil)
        redirect_to admin_professional_path(@professional_profile), notice: 'Acceso reactivado'
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
