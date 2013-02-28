require 'lc3spec/errors'
require 'lc3spec/helpers'

module LC3Spec
  module Expectations
    extend LC3Spec::Helpers

    def self.expect_register(lc3, reporter, reg, val)
      expected = normalize_to_s(val)
      actual = lc3.get_register(reg)

      unless expected == actual
        reporter.report "Incorrect #{reg.to_s}: #{diff(expected, actual)}"
      end
    end

    def self.expect_memory(lc3, reporter, addr, val)
      expected = normalize_to_s(val)
      actual = lc3.get_memory(addr)

      unless expected == actual
        reporter.report "Incorrect mem[#{addr}]: #{diff(expected, actual)}"
      end
    end

    def self.expect_output(lc3, reporter, expected)
      actual = lc3.get_output

      unless ignore_whitespace_equal(expected, actual)
        reporter.report "Incorrect output:\n" +
          "  expected:\n#{strblock(expected)}\n  actual:\n#{strblock(actual)}"
      end
    end

    def self.diff(expected, actual)
      "expected: #{expected}, actual: #{actual}"
    end

    def self.strblock(str, indent = '    ')
      return str if str.nil? or str.empty?
      block = ''
      str.each_line do |line|
        block << indent + line
      end
      block
    end

    def self.ignore_whitespace_equal(lhs, rhs)
      lhs = lhs.each_line.map do |line|
        if line =~ /^\s*$/
          nil
        else
          line.gsub(/[ \t]+/, ' ')
        end
      end.compact.join('').strip

      rhs = rhs.each_line.map do |line|
        if line =~ /^\s*$/
          nil
        else
          line.gsub(/[ \t]+/, ' ')
        end
      end.compact.join('').strip

      lhs == rhs
    end
  end
end
