class Magma
  class IdentifierAttribute < StringAttribute
    def initialize(opts = {})
      super(opts.merge(unique: true))
    end

    private

    def after_magma_model_set
      @magma_model.identity = name
      @magma_model.order(attribute_name) unless @magma_model.order
    end
  end
end
