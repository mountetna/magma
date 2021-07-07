class Magma
  class SubqueryConfig
    attr_reader :magma_class, :condition

    def initialize(magma_class: nil, condition: nil)
      @magma_class = magma_class
      @condition = condition
    end
  end
end
