# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    def create
      rut = sign_up_params[:rut]
      build_resource(sign_up_params)

      if sign_up_params[:name].blank? || rut.blank?
        resource.errors.add(:name, :blank) if sign_up_params[:name].blank?
        resource.build_professional_profile unless resource.professional_profile
        resource.professional_profile.errors.add(:rut, :blank) if rut.blank?
        clean_up_passwords resource
        set_minimum_password_length
        finish_registration_failure
        return
      end

      resource.save
      if resource.persisted?
        profile = resource.professional_profile || resource.build_professional_profile
        profile.rut = rut
        profile.save!
        ValidateProfessionalJob.perform_later(profile.id)
        flash[:ga_event] = { name: 'sign_up', params: { method: 'email' } }

        if resource.active_for_authentication?
          set_flash_message! :notice, :signed_up
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
          set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
          expire_data_after_sign_in!
          respond_with resource, location: after_inactive_sign_up_path_for(resource)
        end
      else
        clean_up_passwords resource
        set_minimum_password_length
        finish_registration_failure
      end
    end

    protected

    def after_sign_up_path_for(resource)
      stored_location_for(resource) || super
    end

    def build_resource(hash = {})
      super(hash.except(:rut, 'rut')).tap do |user|
        user.role = :profesional
      end
    end

    private

    def sign_up_params
      params.expect(user: %i[name email password password_confirmation rut])
    end

    def prepare_registration_failure
      redirect_target = checkout_return_location
      @registration_failure_alert = registration_failure_alert(resource, inline_details: redirect_target.blank?)

      return unless redirect_target

      @registration_failure_redirect = append_auth_tab(redirect_target, 'register')
    end

    def finish_registration_failure
      prepare_registration_failure

      if @registration_failure_redirect
        redirect_to @registration_failure_redirect, alert: @registration_failure_alert, status: :see_other
      else
        flash.now[:alert] = @registration_failure_alert
        render :new, status: :unprocessable_entity
      end
    end

    def checkout_return_location
      location = stored_location_for(:user)
      return if location.blank?
      return unless location.include?('/checkout')

      location
    end

    def append_auth_tab(path, tab)
      uri = URI.parse(path)
      query = Rack::Utils.parse_query(uri.query.to_s)
      query['auth'] = tab
      uri.query = query.to_query.presence
      uri.to_s
    rescue URI::InvalidURIError
      path
    end

    def registration_failure_alert(user, inline_details: false)
      messages = registration_error_messages(user)
      return I18n.t('devise.registrations.failure') if messages.empty?

      return I18n.t('devise.registrations.failure') if inline_details

      if messages.one?
        I18n.t('devise.registrations.failure_with_detail', detail: messages.first)
      else
        I18n.t('devise.registrations.failure_with_details', details: messages.to_sentence)
      end
    end

    def registration_error_messages(user)
      messages = user.errors.full_messages
      profile = user.professional_profile
      messages.concat(profile.errors.full_messages) if profile&.errors&.any?
      messages.uniq
    end
  end
end
