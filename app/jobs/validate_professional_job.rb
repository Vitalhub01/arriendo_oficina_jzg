# frozen_string_literal: true

class ValidateProfessionalJob < ApplicationJob
  queue_as :default

  def perform(professional_profile_id)
    profile = ProfessionalProfile.find(professional_profile_id)
    return if profile.manual_verified? || profile.rejected?

    result = Superintendencia::ValidateRut.new(profile).call

    if result[:valid]
      profile.update!(
        validation_status: :auto_verified,
        superintendencia_data: result[:data],
        rejection_reason: nil
      )
    else
      profile.update!(
        validation_status: :pending,
        superintendencia_data: result[:data]
      )
    end
  end
end
