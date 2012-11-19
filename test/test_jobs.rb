# Slow successful job, does not use timeout algorithm.
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

# Fast successful job, does not use timeout algorithm.
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

# Job that fails quickly, does not use timeout algorithm.
class FailingFastJob
  extend Resque::Plugins::LockTimeout
  @queue = :test

  def self.perform
    raise
    $success += 1
  end
end

# Job that enables the timeout algorithm.
class SlowWithTimeoutJob
  extend Resque::Plugins::LockTimeout
  @queue = :test
  @lock_timeout = 60

  def self.perform
    $success += 1
    sleep 0.2
  end
end

# Job that releases its lock AFTER its expired.
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

# Job that uses a spesific redis connection just for storing locks.
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

# Job that uses a different lock timeout value depending on job args.
class VariableTimeoutJob
  extend Resque::Plugins::LockTimeout
  @queue = :test

  def self.identifier(*args)
    nil
  end

  def self.lock_timeout(extra_timeout)
    3600 * extra_timeout
  end

  def self.perform
    $success += 1
  end
end

# Job to simulate a long running job that refreshes its hold on the lock.
class RefreshLockJob
  extend Resque::Plugins::LockTimeout
  @queue = :test
  @lock_timeout = 60
end

# Job that prevents the job being enqueued if already enqueued/running.
class LonelyJob
  extend Resque::Plugins::LockTimeout
  @queue = :test
  @loner = true

  def self.perform
    $success += 1
    sleep 0.2
  end

  def self.loner_enqueue_failed(*args)
    $enqueue_failed += 1
  end
end

# Exclusive job (only one queued/running) with a timeout.
class LonelyTimeoutJob
  extend Resque::Plugins::LockTimeout
  @queue = :test
  @loner = true
  @lock_timeout = 60

  def self.perform
    $success += 1
    sleep 0.2
  end

  def self.loner_enqueue_failed(*args)
    $enqueue_failed += 1
  end
end

# This job won't complete before it's timeout
class LonelyTimeoutExpiringJob
  extend Resque::Plugins::LockTimeout
  @queue = :test
  @loner = true
  @lock_timeout = 1

  def self.perform
    sleep 2
  end
end
