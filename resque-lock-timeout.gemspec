Gem::Specification.new do |s|
  s.name              = 'resque-lock-timeout'
  s.version           = '0.4.5'
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = 'A Resque plugin adding locking, with optional timeout/deadlock handling to resque jobs.'
  s.license           = 'MIT'
  s.homepage          = 'http://github.com/lantins/resque-lock-timeout'
  s.email             = 'luke@lividpenguin.com'
  s.authors           = ['Luke Antins', 'Ryan Carver', 'Chris Wanstrath']

  s.files             = %w(README.md Rakefile LICENSE HISTORY.md)
  s.files            += Dir.glob('lib/**/*')
  s.files            += Dir.glob('test/**/*')

  s.add_dependency('resque', '~> 1.22')
  s.add_development_dependency('rake', '~> 10.3')
  s.add_development_dependency('minitest', '~> 5.2')
  s.add_development_dependency('yard', '~> 0.8')
  s.add_development_dependency('simplecov', '~> 0.7', '>= 0.7.1')

  s.description       = <<desc
  A Resque plugin. Adds locking, with optional timeout/deadlock handling to
  resque jobs.

  Using a `lock_timeout` allows you to re-acquire the lock should your worker
  fail, crash, or is otherwise unable to relase the lock.

  i.e. Your server unexpectedly looses power. Very handy for jobs that are
  recurring or may be retried.
desc
end
