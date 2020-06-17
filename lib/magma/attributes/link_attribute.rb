class Magma
  class LinkAttribute < ForeignKeyAttribute
    def initialize(opts = {})
      super
      set_link if @magma_model
    end

    def magma_model=(new_magma_model)
      super
      set_link
    end

    private

    def set_link
      @magma_model.many_to_one(
        name,
        class: @magma_model.project_model(link_model_name || name)
      )
    end
  end
end
