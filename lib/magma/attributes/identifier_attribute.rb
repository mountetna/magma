class Magma
  class IdentifierAttribute < StringAttribute
    def initialize(opts = {})
      super(opts.merge(unique: true))
      set_identity if @magma_model
    end

    def magma_model=(new_magma_model)
      super
      set_identity
    end

    private

    def set_identity
      @magma_model.identity = name
      @magma_model.order(attribute_name) unless @magma_model.order
    end
  end
end
