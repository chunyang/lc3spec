require 'spec_helper'

require 'lc3spec/lc3'
require 'lc3spec/helpers'

describe LC3 do
  include LC3Spec::Helpers

  before :all do
    # Does not include :CC
    @registers = %i[R0 R1 R2 R3 R4 R5 R6 R7 PC IR PSR]
  end

  before :each do
    @lc3 = LC3.new
  end

  describe '#get_register' do
    it 'returns register values for valid registers' do
      valid_regexp = /^x[0-9A-F]{4}/

      @registers.each do |register|
        val = @lc3.get_register(register)
        val.should be_kind_of(String)
        val.should match(valid_regexp)
      end

      ['NEGATIVE', 'ZERO', 'POSITIVE'].should include(@lc3.get_register(:CC))
    end

    it 'returns nil for invalid registers' do
      %i[R8 R17 EAX edx rax].each do |register|
        @lc3.get_register(register).should be_nil
      end
    end
  end

  describe '#set_register' do
    it 'sets registers' do
      srand(15)
      values = Array.new(11) { rand(-30000..30000) }
      values.map! { |v| normalize_to_s(v) }

      @registers.each_with_index do |register, idx|
        @lc3.set_register(register, values[idx])
        @lc3.get_register(register).should eq(values[idx])
      end
    end

    it 'raises ArgumentError when trying to set CC with an invalid value' do
      ['xABCD', 5, nil, 'hello'].each do |val|
        expect do
          @lc3.set_register(:CC, val)
        end.to raise_error(ArgumentError)
      end
    end

    it 'returns self' do
      @lc3.set_register(:R1, 'x0017').should == @lc3
    end
  end

  describe '#get_memory' do
    it 'returns memory value given an address' do
      @lc3.get_memory('x0020').should == 'x044C'
      @lc3.get_memory('x0497').should == 'x0FF6'
      @lc3.get_memory('x04B0').should == 'x000A'
    end

    it 'returns x0000 at untouched memory locations' do
      @lc3.get_memory('x6EAD').should == 'x0000'
      @lc3.get_memory('x7B40').should == 'x0000'
      @lc3.get_memory('xABCD').should == 'x0000'
      @lc3.get_memory('xFFF0').should == 'x0000'
    end

    it 'returns memory value given a label' do
      @lc3.get_memory('OS_START').should == 'xE002'
      @lc3.get_memory('TRAP_HALT').should == 'xE021'
      @lc3.get_memory('BAD_INT').should == 'x8000'
    end

    it 'raises ArgumentError when given an invalid label or address' do
      ['NONEXISTENT_LABEL', 'x20302', @lc3].each do |addr|
        expect { @lc3.get_memory(addr) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#set_memory' do
    it 'sets memory at a memory location' do
      @lc3.set_memory('x6000', 'x1234')
      @lc3.set_memory('x7700', 'xABCD')
      @lc3.set_memory('x8880', 'xCAFE')

      @lc3.get_memory('x6000').should == 'x1234'
      @lc3.get_memory('x7700').should == 'xABCD'
      @lc3.get_memory('x8880').should == 'xCAFE'
    end

    it 'sets memory at a label' do
      @lc3.set_memory('TRAP_HALT', 'xCAFE')
      @lc3.set_memory('TRAP_GETC', 'xBEEF')
      @lc3.set_memory('TRAP_PUTSP', 'xDEAD')

      @lc3.get_memory('x048E').should == 'xCAFE'
      @lc3.get_memory('x044C').should == 'xBEEF'
      @lc3.get_memory('x046F').should == 'xDEAD'
    end

    it 'raises ArgumentError when given an invalid label or address' do
      ['NONEXISTENT_LABEL', 'x20302', @lc3].each do |addr|
        expect { @lc3.set_memory addr, 'xDEAD' }.to raise_error(ArgumentError)
      end
    end

    it 'raises ArgumentError when given an invalid value' do
      ['foobar', @lc3].each do |val|
        expect do
          @lc3.set_memory('x6000', val)
        end.to raise_error(ArgumentError)
      end
    end

    it 'sets memory to be the address of an existing label' do
      @lc3.set_memory('x6000', 'TRAP_HALT')
      @lc3.set_memory('OS_R0', 'OS_START')

      @lc3.get_memory('x6000').should == 'x048E'
      @lc3.get_memory('x0447').should == 'x0200'
    end

    it 'returns self' do
      @lc3.set_memory('x1234', 'xABCD').should == @lc3
    end
  end

  describe '#get_address' do
    it 'returns the address of a label' do
      @lc3.get_address('OS_R1').should == 'x0448'
      @lc3.get_address('TRAP_PUTS').should == 'x0456'
      @lc3.get_address('LOW_8_BITS').should == 'x0444'
    end

    it 'returns nil for nonexistent labels' do
      %w[MY_LITTLE_PONY HELLO_WORLD ECE190_ROCKS].each do |label|
        @lc3.get_address(label).should be_nil
      end
    end
  end

  describe '#step' do
    it 'executes one instruction' do
      @lc3.set_register :PC, 'xA000'
      @lc3.get_register(:PC).should == 'xA000'

      @lc3.step
      @lc3.get_register(:PC).should == 'xA001'

      @lc3.step
      @lc3.get_register(:PC).should == 'xA002'
    end
  end
end
