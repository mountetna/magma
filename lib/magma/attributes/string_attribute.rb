class Magma
  class StringAttribute < Attribute
    def initialize(name, model, opts)
      super(name, model, opts.merge(type: String))
    end
  end
end