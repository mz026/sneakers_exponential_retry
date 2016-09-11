# SneakersExponentialRetry

Exponential Retry Handler for [Sneakers](https://github.com/jondot/sneakers) that just works.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sneakers_exponential_retry'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sneakers_exponential_retry

## Usage

Configure your Sneakers by the following:

```ruby
require 'sneakers_exponential_retry'

Sneakers.configure :handler => SneakersExponentialRetry,
                   :handler_options => {
                     :max_retry_count => 3,
                     :logger => Sneakers.logger
                   },
                   :exchange => 'MyExchangeName',
                   :exchange_type => :topic
```

## Options:

- `exchange`: Exchange name to be used, required for `SneakersExponentialRetry`
- `handler_options`:
  - `max_retry_count`: (optional) Max retry count, default to 14
  - `logger`: (optional) logger instance, default to nil, which would not log anything related to retrying.

## How it works:

`SneakersExponentialRetry` handles the behavior of retrying failed jobs exponentially by:

1. On initializing:
  - Create a retry exchange, which is named as `#{queue_name}-retry-ex`
  - Create a retry queue, which is named as `#{queue_name}-retry-queue`
    - Set the `x-dead-letter-exchange` of retry queue to the original job exchange
  - Bind the retry queue to the retry exchange

2. Whenever a job fails, `SneakersExponentialRetry` would:
  - if retry count <= `max_retry_count`
    - publish the job to retry exchange, with an exponential expiration timeout
    - the retry exchange would push the job into our retry queue
    - after the timeout, the job would be published back to the `dead-letter-exchange` of the retry queue, which is our original exchange, so that the job would be retried

  - if retry count > `max_retry_count`
    - reject the job

## Testing:

Run tests by:

```
$ bundle exec rspec
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mz026/sneakers_exponential_retry. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

