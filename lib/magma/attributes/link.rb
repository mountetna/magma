class Magma
  module Link

    # In the event (during model creation) that we use link_model_name to set
    # the model 'type' for a link, we need to use that variable for for model
    # retrieval. Otherwise attribute_name will contain the appropriate model
    # type for a link.
    def link_model
      Magma.instance.get_model(
        @magma_model.project_name,
        link_model_name || attribute_name
      )
    end

    def foreign_id
      :"#{attribute_name}_id"
    end

    # The model name has the project name appended to the front to form the
    # namespace. An example is 'Ipi::Sample'. Here we need to strip off the 
    # project name and append '_id'.
    def self_id
      :"#{@magma_model.name.snake_case.split('::')[1]}_id"
    end

    def link_record(identifier)
      link_model[link_model.identity=> identifier]
    end

    def link_records(identifiers)
      link_model.where(link_model.identity=> identifiers)
    end

    def link_identity
      link_model.attributes[link_model.identity]
    end
  end
end
