class Magma
  class ParentAttribute < ForeignKeyAttribute
    def initialize(opts = {})
      if opts[:attribute_name]
        super
        set_many_to_one if @magma_model
      end
    end

    def magma_model=(new_magma_model)
      super
      set_many_to_one if attribute_name
    end

    private

    def set_many_to_one
      @magma_model.many_to_one(attribute_name.to_sym)
    end
  end
end
