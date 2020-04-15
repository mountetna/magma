class Magma
  class BooleanAttribute < Attribute
    def initialize(name, model, opts)
      super(name, model, opts.merge(type: TrueClass))
    end
  end
end