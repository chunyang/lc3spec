module LC3Spec
  module Dsl
    def set(option, value = true)
      @options ||= {
        :output => $stdout,
        :keep_score => false
      }

      if option == :output
        case value
        when File
          if value.path =~ /\.asm$/
            raise "Not writing output to .asm file"
          end

          @options[:output] = value
        when String
          if value =~ /\.asm$/
            raise "Not writing output to .asm file"
          end

          @options[:output] = open(value, 'w')
        else
          @options[:output] = value
        end

        return @options[:output]
      end

      @options[option] = value

    end

    def configure(&block)
      yield if block_given?
    end

    def test(description, points = 0, &block)
      t = LC3Spec::Test.new(:options => @options,
                            :points => points,
                            &block)

      output = @options[:output]

      if t.pass
        pass(description, points)
      else
        fail(description, points)

        # FIXME: Ugly
        errors = t.reporter.errors.join("\n")

        output.puts errors.each_line.map { |line| '  ' + line }.join('')
        output.puts
      end
    end

    def pass(description, points)
      count_points(:pass, points)

      if !@options[:keep_score] || (points == 0)
        @options[:output].puts "#{description} [OK]"
      else
        @options[:output].puts "#{description} #{points}/#{points}"
      end
    end

    def fail(description, points)
      count_points(:fail, points)

      if !@options[:keep_score] || (points == 0)
        @options[:output].puts "#{description} [FAIL]"
      else
        @options[:output].puts "#{description} 0/#{points}"
      end
    end

    def count_points(result, possible)
      @possible_points ||= 0
      @earned_points ||= 0

      @earned_points += result == :pass ? possible : 0
      @possible_points += possible

      @num_tests ||= 0
      @num_tests += 1

      @num_passed ||= 0
      @num_passed += result == :pass ? 1 : 0
    end

    def print_score
      return if @num_tests.nil? or (@num_tests == 0)

      output = @options[:output]

      if @options[:keep_score]
        output.puts "Score: #@earned_points/#@possible_points"
      else
        if @num_passed == @num_tests
          output.puts "[ALL OK]"
        elsif @num_passed == 0
          output.puts "[ALL FAIL]"
        end
      end
    end
  end
end
