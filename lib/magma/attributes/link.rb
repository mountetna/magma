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
      if [Magma::ChildAttribute, Magma::CollectionAttribute].include?(self.class)
        return link_model.attributes[link_attribute_name.to_sym].column_name.to_sym
      end
      
      :"#{attribute_name}_id"
    end

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
      link_model.attributes[link_model.identity.attribute_name.to_sym]
    end

    private

    def validate
      super
      link_model
    rescue => e
      Magma.instance.logger.log_error(e)
      field = link_model_name ? :link_model_name : :attribute_name
      errors.add(field, "doesn't match an existing model")
    end
  end
end
