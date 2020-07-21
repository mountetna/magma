class Magma
  class IdentifierAttribute < StringAttribute
    def initialize(opts = {})
      @primary_key = opts.delete(:primary_key)
      super(opts.merge(unique: true))
    end

    def primary_key?
      !!@primary_key
    end

    private

    def after_magma_model_set
      @magma_model.identity = self
      @magma_model.order(attribute_name) unless @magma_model.order
    end
  end
end
