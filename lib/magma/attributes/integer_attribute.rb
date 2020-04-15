class Magma
  class IntegerAttribute < Attribute
    def initialize(name, model, opts)
      super(name, model, opts.merge(type: Integer))
    end
  end
end