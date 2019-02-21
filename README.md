# Coque

Create, manage, and interop with shell pipelines from Ruby. Like [Plumbum](https://plumbum.readthedocs.io/en/latest/), for Ruby, with native (Ruby) code streaming integration.

## Installation

Add to your gemfile:

```ruby
gem 'coque'
```

## Usage

Create Coque commands:

```rb
cmd = Coque["echo", "hi"]
# => <Coque::Sh ["echo", "hi"]>
```

And run them:

```rb
res = cmd.run
# => #<Coque::Result:0x007feb5930e408 @out=#<IO:fd 13>, @pid=58688>
res.to_a
# => ["hi"]
```

Or pipe them:

```rb
pipeline = cmd | Coque["wc", "-c"]
# => #<Coque::Pipeline:0x007feb598730b0 @commands=[<Coque::Sh ["echo", "hi"]>, <Coque::Sh ["wc", "-c"]>]>
pipeline.run.to_a
# => ["3"]
```

Coque can also create "Rb" commands, which integrate Ruby code with streaming, line-wise processing of other commands:

```rb
c1 = Coque["printf", '"a\nb\nc\n"']
c2 = Coque.rb { |line| puts line.upcase }
(c1 | c2).run.to_a
# => ["A", "B", "C"]
```

Rb commands can also take "pre" and "post" blocks

```rb
dict = Coque["cat", "/usr/share/dict/words"]
rb_wc = Coque.rb { @lines += 1 }.pre { @lines = 0 }.post { puts @lines }

(dict | rb_wc).run.to_a
# => ["235886"]
```

Commands can have Stdin, Stdout, and Stderr redirected

```rb
(Coque["echo", "hi"] > "/tmp/hi.txt").run.wait
File.read("/tmp/hi.txt")
# => "hi\n"

(Coque["head", "-n", "4"] < "/usr/share/dict/words").run.to_a
# => ["A", "a", "aa", "aal"]

(Coque["cat", "/doesntexist.txt"] >= "/tmp/error.txt").run.wait
File.read("/tmp/error.txt")
# => "cat: /doesntexist.txt: No such file or directory\n"
```

Coque commands can also be derived from a `Coque::Context`, which enables changing directory, setting environment variables, and unsetting child env:

```rb
c = Coque.context
c["pwd"].run.to_a
# => ["/Users/worace/code/coque"]

Coque.context.chdir("/tmp")["pwd"].run.to_a
# => ["/private/tmp"]

Coque.context.setenv("my_key": "pizza")["echo", "$my_key"].run.to_a
# => ["pizza"]

ENV["my_key"] = "pizza"
Coque["echo", "$my_key"].run.to_a
# => ["pizza"]

Coque.context.disinherit_env["echo", "$my_key"].to_a
# => [""]
```

Coque also includes a `Coque.source` helper for feeding Ruby enumerables into shell pipelines:

```rb
(Coque.source(1..500) | Coque["wc", "-l"]).run.to_a
# => ["500"]
```

#### Logging

You can set a logger for Coque, which will be used to output messages when commands are executed:

```rb
Coque.logger = Logger.new(STDOUT)
(Coque["echo", "hi"] | Coque["wc", "-c"]).run!
```

#### Named (Non-Operator) Method Alternatives

The main piping and redirection methods also include named alternatives:

* `|` is aliased to `pipe`
* `>` is aliased to `out`
* `>=` is aliased to `err`
* `<` is aliased to `in`

So these 2 invocations are equivalent:

```rb
(Coque["echo", "hi"] | Coque["wc", "-c"] > STDERR).run!
# is the same as...
Coque["echo", "hi"].pipe(Coque["wc", "-c"]).out(STDERR).run!
```

Will log:

```
I, [2019-02-20T20:31:00.325777 #16749]  INFO -- : Executing Coque Command: <Pipeline <Coque::Sh echo hi> | <Coque::Sh wc -c> >
I, [2019-02-20T20:31:00.325971 #16749]  INFO -- : Executing Coque Command: <Coque::Sh echo hi>
I, [2019-02-20T20:31:00.327719 #16749]  INFO -- : Coque Command: <Coque::Sh echo hi> finished in 0.001683 seconds.
I, [2019-02-20T20:31:00.327771 #16749]  INFO -- : Executing Coque Command: <Coque::Sh wc -c>
I, [2019-02-20T20:31:00.329586 #16749]  INFO -- : Coque Command: <Coque::Sh wc -c> finished in 0.001739 seconds.
I, [2019-02-20T20:31:00.329725 #16749]  INFO -- : Coque Command: <Pipeline <Coque::Sh echo hi> | <Coque::Sh wc -c> > finished in 0.003796 seconds.
```

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

## Building / Releasing

```
gem build coque.gemspec
gem push coque-<VERSION>.gem
git tag <VERSION>
git push origin <VERSION>
```
