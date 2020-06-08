class Magma
  class UpdateAttribute
    def initialize(project_name, action_params = {})
      @project_name = project_name
      @action_params = action_params
    end

    def perform
      @action_params.slice(*Magma::Attribute::EDITABLE_OPTIONS).each do |option, value|
        attribute.update_option(option, value)
      end
    end

    def model
      @model ||= Magma.instance.get_model(
        @project_name,
        @action_params[:model_name]
      )
    end

    def attribute
      @attribute ||= model.attributes[@action_params[:attribute_name].to_sym]
    end

    def validate
      return false unless attribute
      @action_params.except(:action_name, :model_name, :attribute_name).keys.all? do |option|
        attribute.respond_to?(option)
      end
    end
  end
end
