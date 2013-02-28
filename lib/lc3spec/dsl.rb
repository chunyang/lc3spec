module LC3Spec
  module Dsl
    def set(option, value = true)
      @options ||= {
        :output => $stdout
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
        output.puts "#{description} [OK]"
      else
        output.puts "#{description} [FAIL]"

        # FIXME: Ugly
        errors = t.reporter.errors.join("\n")

        output.puts errors.each_line.map { |line| '  ' + line }.join('')
        output.puts
      end
    end
  end
end
