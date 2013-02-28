# LC3Spec

Testing and grading suite for LC-3 assembly programs

# Description

LC3Spec allows you to write tests for LC-3 assembly programs and run
them in the lc3sim simulator. LC3Spec handles assembling code and
creating temporary directories so that you don't have to.

# Requirements

* [lc3tools for unix](http://highered.mcgraw-hill.com/sites/0072467509/student_view0/lc-3_simulator.html)
* Ruby 2.0.0 (Does not work with 1.8.7, untested with 1.9.*)

# TODO

* Documentation
* Tests

# Bugs

* Cannot load two files that have the same basename (e.g., foo/baz.asm and
  bar/baz.asm)
