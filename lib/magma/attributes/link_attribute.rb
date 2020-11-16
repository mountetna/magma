class Magma
  class LinkAttribute < ForeignKeyAttribute
    def revision_to_links(record_name, new_id)
      yield link_model, [ new_id ]
    end

    private

    def after_magma_model_set
      @magma_model.many_to_one(
        name,
        class: @magma_model.project_model(link_model_name || name)
      )
    end
  end
end
