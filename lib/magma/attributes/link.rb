class Magma
  module Link

    # In the event (during model creation) that we use the variable
    # '@link_model' to set the model 'type' for a link, we need to use that
    # variable for for model retrieval. Otherwise the '@name' variable will
    # contain the appropriate model type for a link.
    def link_model
      if @link_model
        return Magma.instance.get_model(@model.project_name, @link_model)
      else
        return Magma.instance.get_model(@model.project_name, @name)
      end
    end

    def foreign_id
      :"#{@name}_id"
    end

    def self_id
      :"#{@model.model_name}_id"
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
