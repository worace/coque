# 1 reverse-engineer the protocol
# SO Post: https://stackoverflow.com/questions/6954116/ruby-s-method-missing-in-python
# A missing method was called.
# The object was <__main__.ProcessLike object at 0x7f31b98a2be0>, the method was 'popen'. 
# It was called with () and {'stdin': <_io.BufferedReader name=3>} as arguments

import tempfile
from tempfile import NamedTemporaryFile
from plumbum import local
from io import StringIO
import io
import os
from collections import namedtuple

# ProcessReturn = namedtuple('ProcessReturn', ['code', 'stderr', 'stdout'])
# first tried namedtuple, but the problem is plumbum
# tries to assign these values crosswise based on the pipeline, and namedtuples
# are immutable, so you run into this:
# dstproc.stderr = srcproc.stderr
# AttributeError: can't set attribute

# Went to dummy ProcessReturn class to try to patch in the gaps
# class ProcessReturn(object):
#   code = 0
#   retcode = 0
#   returncode = 0

#   def wait(self, *args, **kwargs):
#     pass

#   def verify(self, *args, **kwargs):
#     pass

#   def communicate(self, *args, **kwargs):
#     return (self.stdout, self.stderr)

class ProcessLike(object):
  returncode = 0

  # stdin = io.BufferedReader(StringIO())
  # stderr = io.BufferedWriter(StringIO())
  # stdout = io.BufferedWriter(StringIO())

  stdin = io.BytesIO()
  stderr = io.BytesIO()
  stdout = io.BytesIO()
  custom_encoding = None
  run = None
  wait = lambda *args, **kwargs: print('*** DEFAULT WAIT ***')
  srcproc = None
  verify = None

  def __init__(self):
    self.stdin = tempfile.TemporaryFile()
    print('Init stdin:' + str(self.stdin))
    self.stdout = tempfile.TemporaryFile()
    self.stderr = tempfile.TemporaryFile()

  def __setattr__(self, name, value):
    if name in ['stdin', 'stderr', 'stdout', 'custom_encoding', 'run', 'wait', 'srcproc', 'verify']:
      super(ProcessLike, self).__setattr__(name, value)
    else:
      print('*** Attempted to set unknown attr ***')
      print('Attr: ' + name + ', value: ' + str(value))

  def __enter__(self, *args, **kwargs):
    print('*** __enter__ ***')
    print(args)
    print(kwargs)

  def __getattr__(self, name):
    def _missing(*args, **kwargs):
      print("A missing method was called.")
      print("The object was %r, the method was %r. " % (self, name))
      print("It was called with %r and %r as arguments" % (args, kwargs))
    return _missing

  def communicate(self, *args, **kwargs):
    print("tried to communicate with us")
    print(str(args))
    print(str(kwargs))
    return (self.stdout, self.stderr)

  def verify(self, retcode, timeout, stdout, stderr):
    return True

  def __del__(self, *args, **kwargs):
    pass

  # def wait(self, *args, **kwargs):
  #   print('wait' + str(args) + str(kwargs))
  #   print(self.srcproc)
  #   print(self.wait)
  #   # returns returncode
  #   print(self.stdin)
  #   # for line in self.stdin:
  #   #   print(line)
  #   #   print(' '.join(list(line.decode())).rstrip())
  #   #   print(self.stdout)
  #   #   self.stdout.write(' '.join(list(line.decode())).encode())
  #   return 0

  def popen(self, *args, **kwargs):
    print('*** POPEN ProcessLike')
    print(str(args))
    print(str(kwargs))
    return self

  def __or__(self, *args, **kwargs):
    print('ORed ' + str(args) + str(kwargs))

class MyTask(object):
  def __enter__(self):
    self.tempfile = NamedTemporaryFile()
    return self

  def fileno(self):
    return self.tempfile.fileno

  # def __or__(self, other):

  # def __exit__(self, exc_type, exc_value, traceback):
  #   self.tempfile.close()


cmd = local['cat']['/usr/share/dict/words'] | local['head']['-n 5'] | ProcessLike() | local['cat']
code, out, err = cmd.run()
print(out)

