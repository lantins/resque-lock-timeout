module Resque
  module Plugins
    # If you want only one instance of your job running at a time,
    # extend it with this module:
    #
    # require 'resque-lock-timeout'
    #
    # class UpdateNetworkGraph
    #   extend Resque::Plugins::LockTimeout
    #   @queue = :network_graph
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
    # If you wish to limit the durati on a lock may be held for, you can
    # set/override `lock_timeout`. e.g.
    #
    # class UpdateNetworkGraph
    #   extend Resque::Plugins::LockTimeout
    #   @queue = :network_graph
    #
    #   # lock may be held for upto an hour.
    #   @lock_timeout = 3600
    #
    #   def self.perform(repo_id)
    #     heavy_lifting
    #   end
    # end
    #
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
      # The default looks like this:
      # `resque-lock-timeout:<class name>:<identifier>`
      #
      # @param [Array] args job arguments
      # @return [String] redis key
      def redis_lock_key(*args)
        ['lock', name, identifier(*args)].compact.join(":")
      end

      # Number of seconds the lock may be held for.
      # A value of 0 or below will lock without a timeout.
      #
      # @param [Array] args job arguments
      # @return [Fixnum]
      def lock_timeout(*args)
        @lock_timeout ||= 0
      end

      # Convenience method, not used internally.
      #
      # @return [Boolean] true if the job is locked by someone
      def locked?(*args)
        lock_redis.exists(redis_lock_key(*args))
      end

      # @abstract
      # Hook method; called when a were unable to aquire the lock.
      #
      # @param [Array] args job arguments
      def lock_failed(*args)
      end

      # @abstract
      # Hook method; called when the lock expired before we released it.
      #
      # @param [Array] args job arguments
      def lock_expired_before_release(*args)
      end

      # Try to acquire a lock.
      #
      # * Returns false; when unable to acquire the lock.
      # * Returns true; when lock acquired, without a timeout.
      # * Returns timestamp; when lock acquired with a timeout, timestamp is
      #   when the lock timeout expires.
      #
      # @return [Boolean, Fixnum]
      def acquire_lock!(*args)
        acquired = false
        lock_key = redis_lock_key(*args)

        unless lock_timeout(*args) > 0
          # Acquire without using a timeout.
          acquired = true if lock_redis.setnx(lock_key, true)
        else
          # Acquire using the timeout algorithm.
          acquired, lock_until = acquire_lock_algorithm!(lock_key, *args)
        end

        lock_failed(*args) if !acquired
        lock_until && acquired ? lock_until : acquired
      end

      # Attempts to aquire the lock using a timeout / deadlock algorithm.
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
        # Abort if another job holds the lock.
        return unless lock_until = acquire_lock!(*args)

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
