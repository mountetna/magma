class Magma
  class IdentifierAttribute < StringAttribute
    def initialize(name, model, opts)
      super(name, model, opts.merge(unique: true))
      model.identity = name
      model.order(name) unless model.order
    end
  end
end
