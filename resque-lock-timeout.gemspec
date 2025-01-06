require_relative "lib/resque/plugins/lock_timeout/version"

Gem::Specification.new do |s|
  s.name = "ibotta-resque-lock-timeout"
  s.version = Resque::Plugins::LockTimeout::VERSION
  s.date = Time.now.strftime("%Y-%m-%d")
  s.summary = "A Resque plugin adding locking, with optional timeout/deadlock handling to resque jobs."
  s.license = "MIT"
  s.homepage = "http://github.com/Ibotta/resque-lock-timeout"
  s.email = "oss@ibotta.com"
  s.authors = ["Ibotta", "Luke Antins", "Ryan Carver", "Chris Wanstrath"]

  s.files = %w[README.md Rakefile LICENSE HISTORY.md]
  s.files += Dir.glob("lib/**/*")
  s.files += Dir.glob("test/**/*")

  s.add_dependency("resque", "~> 1.23")
  s.add_dependency("redis", ">= 3.3", "< 5")

  s.add_development_dependency("rake")
  s.add_development_dependency("minitest")
  s.add_development_dependency("yard")
  s.add_development_dependency("simplecov")
  s.add_development_dependency("debug")

  s.description = <<-DESC
    A Resque plugin. Adds locking, with optional timeout/deadlock handling to
    resque jobs.

    Using a `lock_timeout` allows you to re-acquire the lock should your worker
    fail, crash, or is otherwise unable to relase the lock.

    i.e. Your server unexpectedly loses power. Very handy for jobs that are
    recurring or may be retried.
  DESC
end
