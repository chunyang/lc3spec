require 'pathname'

module LC3Spec
  module Helpers
    def normalize_to_s(number)
      case number
      when String
        if number =~ /^(?:x|0x|X|0X)?([0-9A-Fa-f]{1,4})$/
          "x#{$1.rjust(4, '0').upcase}"
        else
          raise ArgumentError, "Unable to normalize number: #{number}"
        end
      when Fixnum
        "x#{([number].pack('s>*')).unpack('H*').first.upcase}"
      else
        raise ArgumentError, "Expecting String or Fixnum, got #{number.class}"
      end
    end

    def normalize_to_i(number)
      case number
      when String
        if number =~ /^(?:x|0x|X|0X)?([0-9A-Fa-f]{1,4})$/
          num_part = $1

          if num_part[0].to_i(16) > 7
            num_part = num_part.rjust(4, 'F')
          else
            num_part = num_part.rjust(4, '0')
          end

          [num_part].pack('H*').unpack('s>*').first
        else
          raise ArgumentError, "Unable to normalize number: #{number}"
        end
      when Fixnum
        number
      else
        raise ArgumentError, "Expecting String or Fixnum, got #{number.class}"
      end
    end

    def is_absolute_path?(path)
      Pathname.new(path).absolute?
    end
  end
end
