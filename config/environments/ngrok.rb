# frozen_string_literal: true

# Development over a public HTTPS tunnel (ngrok) for Mercado Pago back_urls / webhooks.
require 'active_support/core_ext/integer/time'

Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  config.active_storage.service = :local
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.assets.quiet = true
  config.assets.check_precompiled_asset = false
  config.active_job.queue_adapter = :sidekiq
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true

  base_url = ENV.fetch('APP_BASE_URL', nil)
  if base_url.blank?
    raise 'APP_BASE_URL is required for RAILS_ENV=ngrok. Run: bin/dev-ngrok'
  end

  uri = URI.parse(base_url)
  tunnel_host = uri.host
  raise "Invalid APP_BASE_URL: #{base_url}" if tunnel_host.blank?

  config.hosts << tunnel_host
  config.hosts << /.*\.ngrok-free\.app/
  config.hosts << /.*\.ngrok\.io/
  config.hosts << /.*\.ngrok\.app/

  url_options = { host: tunnel_host, protocol: 'https' }
  config.action_controller.default_url_options = url_options
  config.action_mailer.default_url_options = url_options

  config.after_initialize do
    Rails.application.routes.default_url_options = url_options
  end
end
