class Magma
  class ParentAttribute < ForeignKeyAttribute
    private

    def after_magma_model_set
      return unless name
      @magma_model.many_to_one(name)
    end
  end
end
