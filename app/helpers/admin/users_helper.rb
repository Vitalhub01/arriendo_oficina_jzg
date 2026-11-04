# frozen_string_literal: true

module Admin
  module UsersHelper
    def password_reset_validity_duration
      Devise.reset_password_within
    end

    def password_reset_validity_label
      distance_of_time_in_words(0, password_reset_validity_duration)
    end

    def whatsapp_share_url(text)
      "https://wa.me/?text=#{ERB::Util.url_encode(text)}"
    end

    def password_reset_whatsapp_message(user:, url:)
      <<~MSG.squish
        Hola #{user.name}, desde #{SeoHelper::SITE_NAME} te compartimos un enlace para crear una nueva contraseña.
        Válido #{password_reset_validity_label} (un solo uso):
        #{url}
      MSG
    end
  end
end
