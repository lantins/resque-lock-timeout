class SlowJob
  extend Resque::Plugins::LockTimeout
  @queue = :test

  def self.perform
    $success += 1
    sleep 0.2
  end

  def self.lock_failed(*args)
    $lock_failed += 1
  end
end

class FastJob
  extend Resque::Plugins::LockTimeout
  @queue = :test

  def self.perform
    $success += 1
  end

  def self.lock_failed(*args)
    $lock_failed += 1
  end
end

class FailingFastJob
  extend Resque::Plugins::LockTimeout
  @queue = :test

  def self.perform
    raise
    $success += 1
  end
end

class SlowWithTimeoutJob
  extend Resque::Plugins::LockTimeout
  @queue = :test
  @lock_timeout = 60

  def self.perform
    $success += 1
    sleep 0.2
  end
end

class ExpireBeforeReleaseJob
  extend Resque::Plugins::LockTimeout
  @queue = :test
  @lock_timeout = 1

  def self.perform
    $success += 1
    sleep 2
  end

  def self.lock_expired_before_release
    $lock_expired = true
  end
end

class SpecificRedisJob
  extend Resque::Plugins::LockTimeout
  @queue = :test

  def self.lock_redis
    @redis
  end

  def self.lock_redis=(redis)
    @redis = redis
  end

  def self.redis_lock_key
    'specific_redis'
  end

  def self.perform
    $success += 1
    sleep 0.2
  end
end