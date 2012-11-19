module Resque
  module Plugins
    # If you want only one instance of your job running at a time,
    # extend it with this module:
    #
    #   require 'resque-lock-timeout'
    #
    #   class UpdateNetworkGraph
    #     extend Resque::Plugins::LockTimeout
    #     @queue = :network_graph
    #
    #     def self.perform(repo_id)
    #       heavy_lifting
    #     end
    #   end
    #
    # If you wish to limit the duration a lock may be held for, you can
    # set/override `lock_timeout`. e.g.
    #
    #   class UpdateNetworkGraph
    #     extend Resque::Plugins::LockTimeout
    #     @queue = :network_graph
    #
    #     # lock may be held for upto an hour.
    #     @lock_timeout = 3600
    #
    #     def self.perform(repo_id)
    #       heavy_lifting
    #     end
    #   end
    #
    # If you wish that only one instance of the job defined by #identifier may be
    # enqueued or running, you can set/override `loner`. e.g.
    #
    #   class PdfExport
    #     extend Resque::Plugins::LockTimeout
    #     @queue = :exports
    #
    #     # only one job can be running/enqueued at a time. For instance a button
    #     # to run a PDF export. If the user clicks several times on it, enqueue
    #     # the job if and only if
    #     #   - the same export is not currently running
    #     #   - the same export is not currently queued.
    #     # ('same' being defined by `identifier`)
    #     @loner = true
    #
    #     def self.perform(repo_id)
    #       heavy_lifting
    #     end
    #   end
    module LockTimeout
      # @abstract You may override to implement a custom identifier,
      #           you should consider doing this if your job arguments
      #           are many/long or may not cleanly cleanly to strings.
      #
      # Builds an identifier using the job arguments. This identifier
      # is used as part of the redis lock key.
      #
      # @param [Array] args job arguments
      # @return [String, nil] job identifier
      def identifier(*args)
        args.join('-')
      end

      # Override to fully control the redis object used for storing
      # the locks.
      #
      # The default is Resque.redis
      #
      # @return [Redis] redis object
      def lock_redis
        Resque.redis
      end

      # Override to fully control the lock key used. It is passed
      # the job arguments.
      #
      # The default looks like this: `lock:<class name>:<identifier>`
      #
      # @param [Array] args job arguments
      # @return [String] redis key
      def redis_lock_key(*args)
        ['lock', name, identifier(*args)].compact.join(':')
      end

      # Builds lock key used by `@loner` option. Passed job arguments.
      #
      # The default looks like this: `loner:lock:<class name>:<identifier>`
      #
      # @param [Array] args job arguments
      # @return [String] redis key
      def redis_loner_lock_key(*args)
        ['loner', redis_lock_key(*args)].compact.join(':')
      end

      # Number of seconds the lock may be held for.
      # A value of 0 or below will lock without a timeout.
      #
      # @param [Array] args job arguments
      # @return [Fixnum]
      def lock_timeout(*args)
        @lock_timeout ||= 0
      end

      # Whether one instance of the job should be running or enqueued.
      #
      # @param [Array] args job arguments
      # @return [TrueClass || FalseClass]
      def loner(*args)
        @loner ||= false
      end

      # Convenience method to check if job is locked and lock did not expire.
      #
      # @return [Boolean] true if the job is locked by someone
      def locked?(*args)
        lock_until = lock_redis.get(redis_lock_key(*args))
        return (lock_until.to_i > Time.now.to_i) if lock_timeout(*args) > 0
        !lock_until.nil?
      end

      # @abstract
      # Hook method; called when a were unable to acquire the lock.
      #
      # @param [Array] args job arguments
      def lock_failed(*args)
      end

      # @abstract
      # Hook method; called when a were unable to enqueue loner job.
      #
      # @param [Array] args job arguments
      def loner_enqueue_failed(*args)
      end

      # @abstract
      # Hook method; called when the lock expired before we released it.
      #
      # @param [Array] args job arguments
      def lock_expired_before_release(*args)
      end

      # @abstract
      # if the job is a `loner`, enqueue only if no other same job
      # is already running/enqueued
      #
      # @param [Array] args job arguments
      def before_enqueue_lock(*args)
        if loner
          if locked?(*args)
            # Same job is currently running
            loner_enqueue_failed(*args)
            false
          else
            acquire_loner_lock!(*args)
          end
        end
      end

      # Try to acquire a lock for running the job.
      # @return [Boolean, Fixnum]
      def acquire_lock!(*args)
        acquire_lock_impl!(:redis_lock_key, :lock_failed, *args)
      end

      # Try to acquire a lock to enqueue a loner job.
      # @return [Boolean, Fixnum]
      def acquire_loner_lock!(*args)
        acquire_lock_impl!(:redis_loner_lock_key, :loner_enqueue_failed, *args)
      end

      # Generic implementation of the locking logic
      #
      # Returns false; when unable to acquire the lock.
      # * Returns true; when lock acquired, without a timeout.
      # * Returns timestamp; when lock acquired with a timeout, timestamp is
      #   when the lock timeout expires.
      #
      # @param [Symbol] lock_key_method the method returning redis key to lock
      # @param [Symbol] failed_hook the method called if lock failed
      # @param [Array] args job arguments
      # @return [Boolean, Fixnum]
      def acquire_lock_impl!(lock_key_method, failed_hook, *args)
        acquired = false
        lock_key = self.send lock_key_method, *args

        unless lock_timeout(*args) > 0
          # Acquire without using a timeout.
          acquired = true if lock_redis.setnx(lock_key, true)
        else
          # Acquire using the timeout algorithm.
          acquired, lock_until = acquire_lock_algorithm!(lock_key, *args)
        end

        self.send(failed_hook, *args) if !acquired
        lock_until && acquired ? lock_until : acquired
      end

      # Attempts to acquire the lock using a timeout / deadlock algorithm.
      #
      # Locking algorithm: http://code.google.com/p/redis/wiki/SetnxCommand
      #
      # @param [String] lock_key redis lock key
      # @param [Array] args job arguments
      def acquire_lock_algorithm!(lock_key, *args)
        now = Time.now.to_i
        lock_until = now + lock_timeout(*args)
        acquired = false

        return [true, lock_until] if lock_redis.setnx(lock_key, lock_until)
        # Can't acquire the lock, see if it has expired.
        lock_expiration = lock_redis.get(lock_key)
        if lock_expiration && lock_expiration.to_i < now
          # expired, try to acquire.
          lock_expiration = lock_redis.getset(lock_key, lock_until)
          if lock_expiration.nil? || lock_expiration.to_i < now
            acquired = true
          end
        else
          # Try once more...
          acquired = true if lock_redis.setnx(lock_key, lock_until)
        end

        [acquired, lock_until]
      end

      # Release the lock.
      #
      # @param [Array] args job arguments
      def release_lock!(*args)
        lock_redis.del(redis_lock_key(*args))
      end

      # Release the enqueue lock for loner jobs
      #
      # @param [Array] args job arguments
      def release_loner_lock!(*args)
        lock_redis.del(redis_loner_lock_key(*args))
      end

      # Refresh the lock.
      #
      # @param [Array] args job arguments
      def refresh_lock!(*args)
        now = Time.now.to_i
        lock_until = now + lock_timeout(*args)
        lock_redis.set(redis_lock_key(*args), lock_until)
      end

      # Where the magic happens.
      #
      # @param [Array] args job arguments
      def around_perform_lock(*args)
        lock_until = acquire_lock!(*args)

        # Release loner lock as job has been dequeued
        release_loner_lock!(*args) if loner

        # Abort if another job holds the lock.
        return unless lock_until

        begin
          yield
        ensure
          # Release the lock on success and error. Unless a lock_timeout is
          # used, then we need to be more careful before releasing the lock.
          unless lock_until === true
            now = Time.now.to_i
            if lock_until < now
              # Eeek! Lock expired before perform finished. Trigger callback.
              lock_expired_before_release(*args)
              return # dont relase lock.
            end
          end
          release_lock!(*args)
        end
      end

    end

  end
end
