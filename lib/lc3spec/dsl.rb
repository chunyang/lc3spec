module LC3Spec
  module Dsl
    def set(option, value = true)
      @options ||= {}
      @options[option] = value
    end

    def configure(&block)
      yield if block_given?
    end

    def test(description, points = 0, &block)
      LC3Spec::Test.new(description,
                        :options => @options,
                        :points => points,
                        &block)
    end
  end
end
