require 'open3'

def banner(msg)
  puts "******* #{msg} *******"
end

def read_from_spawned_pipe
  banner("read_from_spawned_pipe")
  pipe_me_in, pipe_peer_out = IO.pipe
  pipe_peer_in, pipe_me_out = IO.pipe

  pid = spawn('ls',
              out: pipe_peer_out,
              pipe_peer_out => pipe_peer_out,
              in: pipe_peer_in,
              pipe_peer_in => pipe_peer_in)
  puts "Spawned #{pid}"

  pipe_peer_out.close
  puts pipe_me_in.read
end

def read_write_to_spawned
  banner("read_write_to_spawned")
  pipe_me_in, pipe_peer_out = IO.pipe
  pipe_peer_in, pipe_me_out = IO.pipe

  ['a', 'b', 'c', 'ab'].each { |l| pipe_me_out.puts(l) }

  pid = spawn('grep a',
              out: pipe_peer_out,
              pipe_peer_out => pipe_peer_out,
              in: pipe_peer_in,
              pipe_peer_in => pipe_peer_in)
  puts "Spawned #{pid}"
  pipe_me_out.close

  pipe_peer_out.close
  puts pipe_me_in.read
end

def chain_two_native_processes
  banner("chain_two_native_processes")
  a_in_read, a_in_write = IO.pipe
  a_out_read, a_out_write = IO.pipe

  p1 = spawn('echo "a\nb\nc\nab\n"',
             out: a_out_write,
             a_out_write => a_out_write,
             in: a_in_read,
             a_in_read => a_in_read)

  b_out_read, b_out_write = IO.pipe

  p2 = spawn('grep a',
             out: b_out_write,
             b_out_write => b_out_write,
             in: a_out_read,
             a_out_read => a_out_read)

  puts "Spawned a: #{p1}, b: #{p2}"
  # Q: Why do we have to close these? do the spawned processes not close them?
  b_out_write.close
  a_out_write.close
  puts b_out_read.read
end

def reading_large_output
  banner("reading_large_output")
  a_in_read, a_in_write = IO.pipe
  a_out_read, a_out_write = IO.pipe

  p1 = spawn('cat /usr/share/dict/words',
             out: a_out_write,
             a_out_write => a_out_write)

  a_out_write.close
  puts a_out_read.read
end

def pipe_to_forked_ruby
  banner("pipe_to_forked_ruby")
  a_in_read, a_in_write = IO.pipe
  b_out_read, b_out_write = IO.pipe

  ['a', 'b', 'c', 'ab'].each { |l| a_in_write.puts(l) }
  a_in_write.flush
  a_in_write.close

  child = fork do
    # change our stdin to be the read end of the pipe
    STDOUT.puts "forked process to stdout (#{STDOUT.fileno})"
    b_out_write.puts "******* forked process to pipe (#{b_out_write.fileno}) **********"

    a_in_read.each_line { |l| b_out_write.puts "child - #{l}" }
  end
  puts "forked #{child}"

  a_in_write.close
  b_out_write.close

  b_out_read.each_line { |l| puts "read from parent - #{l}" }
end


def native_process_to_ruby_block
  banner("native_process_to_ruby_block")
  # a_in_read, a_in_write = IO.pipe
  a_out_read, a_out_write = IO.pipe
  b_out_read, b_out_write = IO.pipe
  puts "parent file descriptors"
  puts "a read: #{a_out_read.fileno}"
  puts "a write: #{a_out_write.fileno}"
  puts "b read: #{b_out_read.fileno}"
  puts "b write: #{b_out_write.fileno}"

  # Receives copy of a_out_write; closes when done
  p1 = spawn('echo "a\nb\nc\nab"', out: a_out_write)

  # Receives copy of
  # a_out_read - needs to read; closed automatically?
  # a_out_write - doesn't need, close immediately
  # b_out_read - doesn't need, close immediately
  # b_out_write - needs to write; close when done
  child = fork do
    puts "child file descriptors:"
    puts "a read: #{a_out_read.fileno}"
    puts "a write: #{a_out_write.fileno}"
    puts "b read: #{b_out_read.fileno}"
    puts "b write: #{b_out_write.fileno}"
    a_out_write.close
    b_out_read.close

    puts "******* IN FORK **********"

    # while l = a_out_read.gets
    #   puts "working #{l}"
    #   b_out_write.puts "child - #{l}"
    # end

    a_out_read.each_line { |l| puts "working #{l}"; b_out_write.puts "child - #{l}" }
    puts "child done - close writer"
    a_out_read.close
    b_out_write.close
    puts "Fork work done"
  end

  puts "done forked"

  a_out_write.close
  b_out_write.close
  a_out_read.close

  puts "** Display child output:"
  b_out_read.each_line { |l| puts "read from parent - #{l}" }
  b_out_read.close
  puts "done reading"
end

# read_from_spawned_pipe
# read_write_to_spawned
# pipe_to_forked_ruby
# reading_large_output
# chain_two_native_processes
# native_process_to_ruby_block

def run_fork(stdin, stdout, &block)
  fork do
    STDOUT.reopen(stdout)
    stdin.each_line(&block)
  end
end

def three_step
  writers = []
  banner("three step")
  a_in_read, a_in_write = IO.pipe
  a_out_read, a_out_write = IO.pipe

  a_unused = [a_out_write]

  p1 = spawn('echo "a\nb\nc\nab\n"',
             out: a_out_write,
             a_out_write => a_out_write,
             in: a_in_read,
             a_in_read => a_in_read)

  b_out_read, b_out_write = IO.pipe
  b_unused = [b_out_write]

  a_unused.each(&:close)
  run_fork(a_out_read, b_out_write) { |l| puts "~~ - #{l}" }

  c_out_read, c_out_write = IO.pipe
  c_unused = [c_out_write]

  p2 = spawn('grep a',
             out: c_out_write,
             c_out_write => c_out_write,
             in: b_out_read,
             b_out_read => b_out_read)
  b_unused.each(&:close)

  # Q: Why do we have to close these? do the spawned processes not close them?
  c_unused.each(&:close)
  puts c_out_read.read
end

three_step
