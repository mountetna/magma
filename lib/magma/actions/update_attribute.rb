class Magma
  class UpdateAttribute
    def initialize(project_name, action_params = {})
      @project_name = project_name
      @action_params = action_params
    end

    def perform
      model = Magma.instance.get_model(
        @project_name,
        @action_params[:model_name]
      )

      attribute = model.attributes[@action_params[:attribute_name].to_sym]

      @action_params.slice(*Magma::Attribute::EDITABLE_OPTIONS).each do |option, value|
        attribute.update_option(option, value)
      end
    end
  end
end
