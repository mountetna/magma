class Magma
  class RenameAttributeAction < BaseAction
    def perform
      model = Magma.instance.get_model(
        @project_name,
        @action_params[:model_name]
      )

      attribute = model.attributes[@action_params[:attribute_name].to_sym]

      attribute.update(attribute_name: @action_params[:new_attribute_name])

      model.attributes.delete(attribute.column_name.to_sym)
      model.attributes[attribute.attribute_name.to_sym] = attribute

      true
    end
  end
end
