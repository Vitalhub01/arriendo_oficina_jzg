# frozen_string_literal: true

# Ensures only one libvips transform runs at a time per web process (avoids OOM on 512MB).
module ActiveStorageVariantLimiter
  LOCK_KEY = 'active_storage:variant_transform'
  LOCK_TTL_SEC = 180
  WAIT_SEC = 0.25
  MAX_WAIT_SEC = 45

  module VariantWithRecordExtension
    def process
      ActiveStorageVariantLimiter.synchronize { super }
    end
  end

  module VariantExtension
    def process
      ActiveStorageVariantLimiter.synchronize { super }
    end
  end

  def self.synchronize
    return yield unless ENV['REDIS_URL'].present?

    redis = Redis.new(url: ENV['REDIS_URL'])
    token = SecureRandom.hex(8)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_WAIT_SEC

    loop do
      if redis.set(LOCK_KEY, token, nx: true, ex: LOCK_TTL_SEC)
        begin
          return yield
        ensure
          redis.del(LOCK_KEY) if redis.get(LOCK_KEY) == token
        end
      end

      raise 'ActiveStorage variant transform timeout' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep(WAIT_SEC)
    end
  end
end
