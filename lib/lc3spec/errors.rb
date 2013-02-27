module LC3Spec
  class LC3Error < StandardError; end
  class DoesNotAssembleError < LC3Error; end
  class ExpectationNotMetError < LC3Error; end
end
