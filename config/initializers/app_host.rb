# frozen_string_literal: true

# APP_HOST must be hostname only (no scheme/path). Accepts pasted URLs from the dashboard.
if ENV['APP_HOST'].present?
  ENV['APP_HOST'] = ENV['APP_HOST'].sub(%r{\Ahttps?://}i, '').delete_suffix('/')
end
