require File.dirname(__FILE__) + '/test_helper'

class LockTest < MiniTest::Unit::TestCase
  def setup
    $success = $lock_failed = $lock_expired = $enqueue_failed = 0
    Resque.redis.flushall
    @worker = Resque::Worker.new(:test)
  end

  def test_resque_plugin_lint
    # will raise exception if were not a good plugin.
    assert Resque::Plugin.lint(Resque::Plugins::LockTimeout)
  end

  def test_version
    major, minor, patch = Resque::Version.split('.')
    assert_equal 1, major.to_i
    assert minor.to_i >= 7
  end

  def test_can_acquire_lock
    SlowJob.acquire_lock!
    assert_equal true, SlowJob.locked?, 'lock should be acquired'
  end

  def test_can_release_lock
    SlowJob.acquire_lock!
    assert_equal true, SlowJob.locked?, 'lock should be acquired'

    SlowJob.release_lock!
    assert_equal false, SlowJob.locked?, 'lock should have been released'
  end

  def test_lock_failed_callback
    FastJob.acquire_lock!
    assert_equal true, FastJob.locked?, 'lock should be acquired'

    FastJob.acquire_lock!
    assert_equal 1, $lock_failed, 'job callback should increment lock_failed'
  end

  def test_lock_without_timeout
    3.times { Resque.enqueue(SlowJob) }

    workers = []
    3.times do
      workers << Thread.new { @worker.process }
    end
    workers.each { |t| t.join }

    assert_equal 1, $success, 'job should increment success'
  end

  def test_lock_is_released_on_success
    Resque.enqueue(FastJob)
    @worker.process
    assert_equal 1, $success, 'job should increment success'
    assert_equal false, FastJob.locked?, 'lock should have been released'
  end

  def test_lock_is_released_on_failure
    Resque.enqueue(FailingFastJob)
    @worker.process
    assert_equal 0, $success, 'job shouldnt increment success'
    assert_equal false, FastJob.locked?, 'lock should have been released'
  end

  def test_can_acquire_lock_with_timeout
    now = Time.now.to_i
    assert SlowWithTimeoutJob.acquire_lock!, 'acquire lock'

    lock = Resque.redis.get(SlowWithTimeoutJob.redis_lock_key)
    assert (now + 58) < lock.to_i, 'lock expire time should be in the future'
  end

  def test_lock_recovers_after_lock_timeout
    now = Time.now.to_i
    assert SlowWithTimeoutJob.acquire_lock!, 'acquire lock'
    assert_equal false, SlowWithTimeoutJob.acquire_lock!, 'acquire lock fails'

    Resque.redis.set(SlowWithTimeoutJob.redis_lock_key, now - 40) # haxor timeout.
    assert SlowWithTimeoutJob.acquire_lock!, 'acquire lock, timeout expired'

    lock = Resque.redis.get(SlowWithTimeoutJob.redis_lock_key)
    assert (now + 58) < lock.to_i
  end

  def test_lock_with_timeout
    3.times { Resque.enqueue(SlowWithTimeoutJob) }

    workers = []
    3.times do
      workers << Thread.new { @worker.process }
    end
    workers.each { |t| t.join }

    assert_equal 1, $success, 'job should increment success'
  end

  def test_lock_expired_before_release
    Resque.enqueue(ExpireBeforeReleaseJob)
    @worker.process
    assert_equal 1, $success, 'job should increment success'
    assert_equal true, $lock_expired, 'should be set by callback method'
    assert_equal false, FastJob.locked?, 'lock should not release'
  end

  def test_lock_with_specific_redis
    lock_redis = Redis.new(:host => Resque.redis.client.host,
                           :port => Resque.redis.client.port,
                           :db => 'locks',
                           :threadsafe => true)
    SpecificRedisJob.lock_redis = lock_redis
    Resque.enqueue(SpecificRedisJob)

    thread = Thread.new { @worker.process }

    sleep 0.1
    # this is nil in Resque.redis since we make no attempt to add a resque:
    # prefix to the key
    assert_nil Resque.redis.get('specific_redis')
    assert lock_redis.get('specific_redis')

    thread.join
    assert_nil lock_redis.get('specific_redis')
    assert_equal 1, $success, 'job should increment success'
  end

  def test_lock_timeout_accepts_job_args
    # setup our time values.
    now = Time.now.to_i
    one_hour_ahead = now + 3600
    twelve_hours_ahead = (now + (3600 * 12))

    # 1 hour ahead.
    assert VariableTimeoutJob.acquire_lock!(1) >= one_hour_ahead, 'lock should be 1 hour ahead'
    VariableTimeoutJob.release_lock!

    # 12 hours ahead.
    assert VariableTimeoutJob.acquire_lock!(12) >= twelve_hours_ahead, 'lock should be 12 hours ahead'
    VariableTimeoutJob.release_lock!
  end

  def test_refresh_lock!
    # grab the lock.
    RefreshLockJob.acquire_lock!
    sleep 2

    # grab the initial lock timeout then refresh the lock.
    initial_lock = Resque.redis.get(RefreshLockJob.redis_lock_key).to_i
    RefreshLockJob.refresh_lock!

    # lock should now be at least 1 second more then the initial lock.
    latest_lock = Resque.redis.get(RefreshLockJob.redis_lock_key).to_i
    diff = latest_lock - initial_lock
    assert diff >= 1, 'diff between initial lock and refreshed lock should be at least 1 second'
  end

  def test_cannot_enqueue_two_loner_jobs
    Resque.enqueue(LonelyJob)
    Resque.enqueue(LonelyJob)
    assert_equal 1, Resque.size(:test), '1 job should be enqueued'

    Resque.enqueue(LonelyTimeoutJob)
    Resque.enqueue(LonelyTimeoutJob)
    assert_equal 2, Resque.size(:test), '2 jobs should be enqueued'
  end

  def test_loner_job_should_not_be_enqued_if_already_running
    Resque.enqueue(LonelyJob)
    thread = Thread.new { @worker.process }

    sleep 0.1 # The LonelyJob should be running (perfom is 0.2 seconds long)
    Resque.enqueue(LonelyJob)
    assert_equal 0, Resque.size(:test)
    assert_equal 1, $enqueue_failed, 'One job callback should increment enqueue_failed'

    thread.join
    assert_equal 1, $success, 'One job should increment success'
  end

  def test_loner_job_with_timeout_should_not_be_enqued_if_already_running
    Resque.enqueue(LonelyTimeoutJob)
    thread = Thread.new { @worker.process }

    sleep 0.1 # Job should be running (perfom is 0.2 seconds long)
    Resque.enqueue(LonelyTimeoutJob)
    assert_equal 0, Resque.size(:test)
    assert_equal 1, $enqueue_failed, 'One job callback should increment enqueue_failed'

    thread.join
    assert_equal 1, $success, 'One job should increment success'
  end

  def test_loner_job_should_get_enqueued_if_timeout_expired
    Resque.enqueue(LonelyTimeoutExpiringJob)
    thread = Thread.new { @worker.process }

    sleep 2.1 # Wait for job to finish.

    Resque.enqueue(LonelyTimeoutExpiringJob)
    assert_equal 1, Resque.size(:test), "Should be able to enqueue a loner job if one previously finished after the timeout"
  end

end
