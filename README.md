Resque Lock Timeout
===================

A [Resque][rq] plugin. Requires Resque 1.8.0.

resque-lock-timeout adds locking, with optional timeout/deadlock handling to
resque jobs.

Using a `lock_timeout` allows you to re-aquire the lock should your worker
fail, crash, or is otherwise unable to relase the lock. **i.e.** Your server
unexpectedly looses power. Very handy for jobs that are recurring or may be
retried.

Usage / Examples
----------------

### Single Job Instance

    require 'resque-lock-timeout'

    class UpdateNetworkGraph
      extend Resque::Plugins::LockTimeout
      @queue = :network_graph

      def self.perform(repo_id)
        heavy_lifting
      end
    end

Locking is achieved by storing a identifyer/lock key in Redis.

Default behaviour...

* Only one instance of a job may execute at once.
* The lock is held until the job completes or fails.
* If another job is executing with the same arguments the job will abort.

Please see below for more information about the identifer/lock key.

### With Lock Expiry/Timeout

The locking algorithm used can be found in the [Redis SETNX][redis-setnx]
documentation.

Simply set the lock timeout in seconds, e.g.

    class UpdateNetworkGraph
      extend Resque::Plugins::LockTimeout
      @queue = :network_graph

      # Lock may be held for upto an hour.
      @lock_timeout = 3600

      def self.perform(repo_id)
        heavy_lifting
      end
    end

Customise & Extend
==================

### Job Identifier/Lock Key

The key is built using the `identifier`. If you have a lot of arguments or
really long ones, you should consider overriding `identifier` to define a
more precise or loose custom identifier.

The default identifier is just your job arguments joined with a dash `-`.

By default the key uses this format: 
`resque-lock-timeout:<job class name>:<identifier>`.

Or you can define the entire key by overriding `redis_lock_key`.

    class UpdateNetworkGraph
      extend Resque::Plugins::LockTimeout
      @queue = :network_graph

      # Run only one at a time, regardless of repo_id.
      def self.identifier(repo_id)
        nil
      end

      def self.perform(repo_id)
        heavy_lifting
      end
    end

The above modification will ensure only one job of class
UpdateNetworkGraph is running at a time, regardless of the
repo_id.

It's lock key would be: `resque-lock-timeout:UpdateNetworkGraph`.

### Redis Connection Used for Locking

By default all locks are stored via Resque's redis connection. If you wish to
change this you may override `lock_redis`.

    class UpdateNetworkGraph
      extend Resque::Plugins::LockTimeout
      @queue = :network_graph

      def self.lock_redis
        @lock_redis ||= Redis.new
      end

      def self.perform(repo_id)
        heavy_lifting
      end
    end

### Callbacks

Several callbacks are available to override and implement your own logic, e.g.

    class UpdateNetworkGraph
      extend Resque::Plugins::Lock
      @queue = :network_graph

      # Lock may be held for upto an hour.
      @lock_timeout = 3600

      # Job failed to acquire lock. You may implement retry or other logic.
      def self.lock_failed(repo_id)
        raise LockFailed
      end

      # Job has complete; but the lock expired before we could relase it.
      # The lock wasn't released; as its *possible* the lock is now held
      # by another job.
      def self.lock_expired_before_release(repo_id)
        handle_if_needed
      end

      def self.perform(repo_id)
        heavy_lifting
      end
    end

Install
=======

    $ gem install resque-lock-timeout

Acknowledgements
================

Forked from Chris Wanstrath' [resque-lock][resque-lock] plugin.
Lock timeout from Ryan Carvar' [resque-lock-retry][resque-lock-retry] plugin.
And a little tinkering from Luke Antins.

[rq]: http://github.com/defunkt/resque
[redis-setnx]: http://code.google.com/p/redis/wiki/SetnxCommand
[resque-lock]: http://github.com/defunkt/resque-lock
[resque-lock-retry]: http://github.com/rcarver/resque-lock-retry