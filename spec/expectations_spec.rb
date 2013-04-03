require 'spec_helper'

require 'lc3spec/lc3'
require 'lc3spec/expectations'

describe 'Expectations' do
  before :each do
    @lc3 = LC3.new
    @reporter = double('reporter')
  end

  describe '#expect_nonempty' do
    it 'reports when a file is empty' do
      @reporter.should_receive(:report)
      LC3Spec::Expectations.expect_nonempty(@lc3, @reporter,
          File.join(File.dirname(__FILE__), 'resources/empty.obj'))
    end

    it 'reports when a file only has .ORIG and .END' do
      @reporter.should_receive(:report)
      LC3Spec::Expectations.expect_nonempty(@lc3, @reporter,
          File.join(File.dirname(__FILE__), 'resources/almost_empty.obj'))
    end

    it 'does not report when a file has code' do
      @reporter.should_not_receive(:report)
      LC3Spec::Expectations.expect_nonempty(@lc3, @reporter,
          File.join(File.dirname(__FILE__), 'resources/labels.obj'))
    end
  end
end
