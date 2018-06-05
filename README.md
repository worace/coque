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

## Further Reading / Prior Art

The concept and API for this library was heavily inspired by Python's excellent [Plumbum](https://plumbum.readthedocs.io/en/latest/) library.

I relied on many resources to understand Ruby's great facilities for Process creation and manipulation. Some highlights include:

* Avdi Grimm's _A dozen (or so) ways to start sub-processes in Ruby_ ([Part 1](https://devver.wordpress.com/2009/06/30/a-dozen-or-so-ways-to-start-sub-processes-in-ruby-part-1/), [Part 2](https://devver.wordpress.com/2009/07/13/a-dozen-or-so-ways-to-start-sub-processes-in-ruby-part-2/), [Part 3](https://devver.wordpress.com/2009/10/12/ruby-subprocesses-part_3/))
* Ryan Tomayko's [I like Unicorn because it's Unix](https://tomayko.com/blog/2009/unicorn-is-unix)
* Jesse Storimer's [Working With Unix Processes](https://www.jstorimer.com/products/working-with-unix-processes)
* Brandon Wamboldt's blog series: [How bash redirection works](https://brandonwamboldt.ca/how-bash-redirection-works-under-the-hood-1512/), [How Linux pipes work](https://brandonwamboldt.ca/how-linux-pipes-work-under-the-hood-1518/), and [Understanding how Linux creates processes](https://brandonwamboldt.ca/how-linux-creates-processes-1528/)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Coque project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[worace]/coque/blob/master/CODE_OF_CONDUCT.md).
