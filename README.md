# Coque

## Installation

Add to your gemfile:

```ruby
gem 'coque'
```

## Usage

### Streaming Performance

Should be little overhead compared with the equivalent pipeline from a standard shell.

From zsh:

```
head -c 100000000 /dev/urandom | pv | wc -c
95.4MiB 0:00:06 [14.1MiB/s] [      <=>      ]
 100000000
```

With coque:

```rb
p = Coque["head", "-c", "100000000", "/dev/urandom"] | Coque["pv"] | Coque["wc", "-c"]
p.run.wait
95.4MiB 0:00:06 [14.6MiB/s] [           <=> ]
```

## Development

* Setup local environment with standard `bundle`
* Run tests with `rake`
* See code coverage output in `coverage/`
* Start a pry console with `bin/console`
* Install current dev version with `rake install`
* Use `rake release` to release after bumping `lib/coque/version.rb`
* New issues welcome

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Coque project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[worace]/coque/blob/master/CODE_OF_CONDUCT.md).
