# frozen_string_literal: true

# Mobile Chrome often drops the session on return from Mercado Pago (cross-site redirect via
# back_urls) unless the session cookie declares SameSite and Secure on HTTPS.
Rails.application.config.action_dispatch.cookies_same_site_protection = :lax

secure_session = Rails.env.production? || ENV['RAILS_ENV'] == 'ngrok'

session_options = {
  same_site: :lax,
  httponly: true
}
session_options[:secure] = true if secure_session

Rails.application.config.session_store :cookie_store, **session_options
