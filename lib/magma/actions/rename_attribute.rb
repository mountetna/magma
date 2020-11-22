class Magma
  class RenameAttributeAction < BaseAction
    def perform
      @original_attribute_name = attribute.attribute_name.to_sym

      model.attributes.delete(@original_attribute_name)
      attribute.update(attribute_name: @action_params[:new_attribute_name])
      model.attributes[attribute.attribute_name.to_sym] = attribute

      true
    end

    def target_models
      if model
        [model]
      else
        []
      end
    end

    private

    def validations
      [:validate_attribute_exists, :validate_new_attribute_name]
    end

    def validate_attribute_exists
      return if attribute

      @errors << Magma::ActionError.new(
        message: 'Attribute does not exist',
        source: @action_params.slice(:attribute_name, :model_name)
      )
    end

    def validate_new_attribute_name
      return unless attribute
      validation_attribute = attribute.dup
      validation_attribute.set(attribute_name: @action_params[:new_attribute_name])

      return if validation_attribute.valid?

      validation_attribute.errors.full_messages.each do |error|
        @errors << Magma::ActionError.new(
          message: error,
          source: @action_params.slice(:model_name, :new_attribute_name)
        )
      end
    end

    def attribute
      @attribute ||= model.attributes[@action_params[:attribute_name].to_sym]
    end

    def model
      @model ||= Magma.instance.get_model(
        @project_name,
        @action_params[:model_name]
      )
    end
  end
end
