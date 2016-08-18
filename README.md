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

TODO

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

