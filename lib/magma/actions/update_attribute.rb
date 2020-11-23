class Magma
  class UpdateAttributeAction < BaseAction
    def perform
      attribute.update(@action_params.slice(*Magma::Attribute::EDITABLE_OPTIONS))
    rescue Sequel::ValidationFailed => e
      Magma.instance.logger.log_error(e)

      @errors << Magma::ActionError.new(
        message: 'Update attribute failed',
        source: @action_params.slice(:attribute_name, :model_name),
        reason: e
      )

      attribute.initial_values.keys.each { |name| attribute.reset_column(name) }
    ensure
      return @errors.empty?
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
      [:validate_attribute_exists, :validate_options, :validate_changes, :validate_restricted_attribute]
    end

    def validate_attribute_exists
      return if attribute

      @errors << Magma::ActionError.new(
        message: 'Attribute does not exist',
        source: @action_params.slice(:attribute_name, :model_name)
      )
    end

    def validate_options
      return unless attribute

      @action_params.except(:action_name, :model_name, :attribute_name).keys.each do |option|
        if restricted_options.include?(option)
          @errors << Magma::ActionError.new(
            message: "#{option.to_s} cannot be changed",
            source: @action_params.slice(:action_name, :model_name, :attribute_name)
          )
        elsif !attribute.respond_to?(option)
          @errors << Magma::ActionError.new(
            message: "Attribute does not implement #{option}",
            source: @action_params.slice(:action_name, :model_name, :attribute_name)
          )
        end
      end
    end

    def validate_changes
      return unless attribute
      validation_attribute = attribute.dup
      validation_attribute.set(@action_params.slice(*Magma::Attribute::EDITABLE_OPTIONS))
      return if validation_attribute.valid?

      validation_attribute.errors.full_messages.each do |error|
        @errors << Magma::ActionError.new(
          message: error,
          source: @action_params.slice(:model_name, :attribute_name)
        )
      end
    end

    def validate_restricted_attribute
      return if @action_params[:attribute_name] != 'restricted' || !@action_params[:restricted]

      @errors << Magma::ActionError.new(
          message: "restricted column may not, itself, be restricted",
          source: @action_params.slice(:project_name, :model_name, :attribute_name, :restricted)
      )
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

    def restricted_options
      @restricted_options ||= [:name, :new_attribute_name]
    end
  end
end
