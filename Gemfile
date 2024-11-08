source 'https://rubygems.org'

case resque_version = ENV.fetch('RESQUE', 'latest')
when 'master'
  gem 'resque', git: 'https://github.com/resque/resque'
when /^git:/, /^https:/
  gem 'resque', git: resque_version
when 'latest'
  gem 'resque'
else
  versions = resque_version.split(',')
  gem 'resque', *versions
end

case redis_version = ENV.fetch('REDIS_VERSION', 'latest')
when 'master'
  gem 'redis', git: 'https://github.com/redis/redis-rb'
when /^git:/, /^https:/
  gem 'redis', git: redis_version
when 'latest'
  gem 'redis'
else
  versions = redis_version.split(',')
  gem 'redis', *versions
end

gemspec
