## HEAD (branch: resque-2)

* Test against resque v2.0

## 0.5.0 (2020-10-02)

- Dirty Exit Lock Implementation.

## 0.4.5 (2015-08-04)

- Fix: ensure exceptions are kept if raised **after** lock timeout expires.

## 0.4.4 (2014-02-21)

- Add: `enqueued?` and `loner_locked?` helper methods.
- Bump minimum version of resque to v1.22

## 0.4.1 (2012-11-19)

- Fix: allow `@loner` job to be enqueued if timeout expires.

## 0.4.0 (2012-11-09)

- Add: `@loner` boolean option to prevent job being enqueued if already
  running/enqueued. (Thanks to @ssaunier)

## 0.3.3 (2012-03-09)

- Tested against v1.20.0 of resque.

## 0.3.1 (2011-07-16)

- Pass job arguments to `lock_timeout`. (Bob Potter)
- Added `refresh_lock!` method for long running jobs. (Bob Potter)

## 0.3.0 (2011-07-16)

- Ability to customize redis connection used for storing locks.
  (thanks Richie Vos =))
- Added Bundler `Gemfile`.
- Added abstract stub methods for callback methods:
  `lock_failed`, `lock_expired_before_release`

## 0.2.1 (2010-06-16)

- Relax gemspec dependancies.

## 0.2.0 (2010-05-05)

- Initial release as `resque-lock-timeout`, forked from Chris Wanstrath'
  `resque-lock`.
