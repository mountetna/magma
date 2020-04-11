class Magma
  class JsonAttribute < Attribute
    def initialize(name, model, opts)
      super(name, model, opts.merge(type: :json))
    end
  end
end