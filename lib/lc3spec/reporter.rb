module LC3Spec
  class Reporter
    def initialize
      @reports = []
    end

    def report(msg)
      @reports << msg
    end

    def pass?
      @reports.empty?
    end

    def fail?
      not @reports.empty?
    end

    def errors
      @reports.dup
    end
  end
end
