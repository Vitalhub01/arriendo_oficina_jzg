# frozen_string_literal: true

module Users
  class CreatePasswordResetRequest
    def initialize(email:)
      @email = email.to_s.strip.downcase
    end

    def call
      return if @email.blank?

      existing = PasswordResetRequest
                 .pending
                 .where(email: @email)
                 .where(created_at: PasswordResetRequest::GROUPING_WINDOW.ago..)
                 .order(created_at: :desc)
                 .first
      return existing if existing

      user = User.find_by(email: @email)

      PasswordResetRequest.create!(
        email: @email,
        user: user,
        status: :pending
      )
    end
  end
end
