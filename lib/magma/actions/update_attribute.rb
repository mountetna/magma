require_relative 'action_error'

class Magma
  class UpdateAttributeAction
    def initialize(project_name, action_params = {})
      @project_name = project_name
      @action_params = action_params
      @errors = []
    end

    def perform
      @action_params.slice(*Magma::Attribute::EDITABLE_OPTIONS).each do |option, value|
        attribute.update_option(option, value)
      rescue => e
        @errors << Magma::ActionError.new(message: 'Update attribute failed', source: @action_params.slice(:attribute_name, :model_name), reason: e)
      end
      return @errors.empty?
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
      if attribute
        @action_params.except(:action_name, :model_name, :attribute_name).keys.each do |option|
          next if check_restricted_attributes(option)
          unless attribute.respond_to?(option)
            @errors << Magma::ActionError.new(message: "Attribute does not implement #{option}", source: @action_params.slice(:action_name, :model_name, :attribute_name))
          end
        end
      else
        @errors << Magma::ActionError.new(message: 'Attribute does not exist', source: @action_params.slice(:attribute_name, :model_name))
      end
      return @errors.empty?
    end

    def errors
      @errors.map(&:to_h)
    end

    private

    def check_restricted_attributes(option)
      if option == :name || option == :new_attribute_name
        @errors << Magma::ActionError.new(message: "#{option.to_s} cannot be changed", source: @action_params.slice(:action_name, :model_name, :attribute_name))
        true
      end
      false
    end
  end
end
