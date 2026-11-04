# frozen_string_literal: true

module Users
  class IssuePasswordResetLink
    def initialize(user:)
      @user = user
    end

    def call(url_options:)
      raw_token = @user.send(:set_reset_password_token)
      url = Rails.application.routes.url_helpers.edit_user_password_url(
        reset_password_token: raw_token,
        **url_options
      )
      Result.new(url: url)
    end

    class Result
      attr_reader :url

      def initialize(url:)
        @url = url
      end
    end
  end
end
