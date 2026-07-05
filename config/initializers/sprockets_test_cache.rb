# frozen_string_literal: true

if Rails.env.test?
  Rails.application.config.to_prepare do
    test_cache_path = Rails.root.join('tmp/test-sprockets-cache')
    FileUtils.mkdir_p(test_cache_path)

    Rails.application.config.assets.configure do |env|
      env.cache = Sprockets::Cache::FileStore.new(test_cache_path.to_s)
    end
  end
end
