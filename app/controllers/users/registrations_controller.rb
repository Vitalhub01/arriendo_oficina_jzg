# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    def create
      rut = sign_up_params[:rut]
      if sign_up_params[:name].blank? || rut.blank?
        self.resource = build_resource(sign_up_params)
        resource.errors.add(:name, :blank) if sign_up_params[:name].blank?
        resource.build_professional_profile unless resource.professional_profile
        resource.professional_profile.errors.add(:rut, :blank) if rut.blank?
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
        return
      end

      super do |user|
        next unless user.persisted?

        profile = user.professional_profile || user.build_professional_profile
        profile.rut = rut
        profile.save!
        ValidateProfessionalJob.perform_later(profile.id)
        flash[:ga_event] = { name: 'sign_up', params: { method: 'email' } }
      end
    end

    protected

    def build_resource(hash = {})
      super(hash).tap do |user|
        user.role = :profesional
      end
    end

    private

    def sign_up_params
      params.expect(user: %i[name email password password_confirmation rut])
    end
  end
end
