# LC3Spec

Testing and grading suite for LC-3 assembly programs

# Description

LC3Spec allows you to write tests for LC-3 assembly programs and run
them in the lc3sim simulator. LC3Spec handles assembling code and
creating temporary directories so that you don't have to.

LC3Spec executes spec files that each describe a number of tests.
Each test runs a new instance of lc3sim and allows you to interact
with it programmatically.

Consider the following assembly file, regs.asm, which is supposed to
set registers R0, R1, R2, R3, and R4 to 0, 1, 2, 3, and 4, respectively:

```
    .ORIG x4000
    AND R0, R0, 0
    ADD R1, R0, 1
    ADD R2, R0, 2
    ADD R3, R0, 3
    HALT
    .END
```

We can write a spec, spec.rb, to test it:

```ruby
test 'Register Expectations' do
  file 'regs'
  set_breakpoint 'TRAP_HALT'
  continue

  expect_register R0, 0
  expect_register R1, 1
  expect_register R2, 2
  expect_register R3, 3
  expect_register R4, 4
end
```

Running with `lc3spec spec.rb`:

```
Register Expectations [FAIL]
  Incorrect R4: expected: x0004, actual: x0000
```

Oops, looks like we forgot to initialize R4. If we go back and add
`ADD R4, R0, 4` to regs.asm and rerun the spec, we'll see:

```
Register Expectations [OK]
```

LC3Spec handles assembling files behind the scenes, a temporary directory
is created to perform each test and all generated files (.obj, .sym) are
discarded at the end of each test.

## Configuration

Configuration is performed by using `set :option, value`. Configuration
changes can be enclosed in a `configure do ... end` block:

```ruby
configure do
  set :output, 'feedback.txt'
  set :keep_score, true
end
```

There are currently two supported options:

* `:output` - filename or file to write output to, default is `$stdout`
* `:keep_score` - whether or not to display score for each test. If false,
  only `[OK]` or `[FAIL]` are displayed, if true, a fractional score
  is displayed, e.g., `0/1` or `4/4`

An example:

```ruby
configure do
  set :output, 'feedback.txt'
  set :keep_score, true
end

test 'this is worth 1 point', 1 do
  # ...
end

test 'this is worth 4 points', 4 do
  # ...
end

test 'this should fail', 2 do
  set_register R4, 'xFACE'
  expect_register R4, 'xCAFE'
end

print_score
```

The print_score method prints the total score at the end of the file.
Running the above spec will produce the following output in feedback.txt:

```
this is worth 1 point 1/1
this is worth 4 points 4/4
this should fail 0/2
  Incorrect R4: expected: xCAFE, actual: xFACE

Score: 5/7
```

# Requirements

* [lc3tools for unix](http://highered.mcgraw-hill.com/sites/0072467509/student_view0/lc-3_simulator.html)
* Ruby 2.0.0 (Does not work with 1.8.7, untested with 1.9.*)

# Install

```
gem install lc3spec
```

# TODO

* Documentation
* Tests
* Better expectations, e.g., for arrays or strings in memory

# Bugs

* Cannot load two files that have the same basename (e.g., foo/baz.asm and
  bar/baz.asm)
