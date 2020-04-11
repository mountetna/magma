class Magma
  class FloatAttribute < Attribute
    def initialize(name, model, opts)
      super(name, model, opts.merge(type: Float))
    end
  end
end