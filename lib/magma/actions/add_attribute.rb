class Magma
  class AddAttributeAction < BaseAction
    def perform
      save_attribute
      return false if @errors.any?

      model.load_attributes([attribute])
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

    def save_attribute
      attribute.save
    rescue Sequel::ValidationFailed => e
      Magma.instance.logger.log_error(e)
      @errors << Magma::ActionError.new(
        message: 'Create attribute failed',
        source: @action_params.slice(:project_name, :model_name),
        reason: e
      )
    end

    def validations
      [
        :validate_model,
        :validate_type,
        :validate_attribute_name_unique,
        :validate_restricted_attribute,
        :validate_options,
        :validate_not_link,
        :validate_attribute,
      ]
    end

    def validate_type
      return if Magma::Attribute.attribute_types.include?(@action_params[:type])

      @errors << Magma::ActionError.new(
        message: 'Type is invalid',
        source: @action_params.slice(:action_name, :model_name)
      )
    end

    def validate_model
      return if model

      @errors << Magma::ActionError.new(
        message: 'Model does not exist',
        source: @action_params.slice(:action_name, :model_name)
      )
    end

    def validate_not_link
      return unless attribute.is_a?(Magma::ChildAttribute) || attribute.is_a?(Magma::CollectionAttribute) || attribute.is_a?(Magma::ForeignKeyAttribute)

      @errors << Magma::ActionError.new(
          message: "type cannot be a relation, use add_link instead.",
          source: @action_params.slice(:type)
      )
    end

    def validate_attribute_name_unique
      return if !model&.has_attribute?(attribute&.attribute_name)

      @errors << Magma::ActionError.new(
        message: "attribute_name already exists on #{model.name}",
        source: @action_params.slice(:project_name, :model_name, :attribute_name)
      )
    end

    def validate_restricted_attribute
      return if @action_params[:attribute_name] != 'restricted' || !@action_params[:restricted]

      @errors << Magma::ActionError.new(
          message: "restricted column may not, itself, be restricted",
          source: @action_params.slice(:project_name, :model_name, :attribute_name, :restricted)
      )
    end

    def validate_options
      return unless model && attribute
      @action_params.except(:action_name, :model_name, :attribute_name).keys.each do |option|
        if !attribute.respond_to?(option)
          @errors << Magma::ActionError.new(
            message: "Attribute does not implement #{option}",
            source: @action_params.slice(:action_name, :model_name, :attribute_name)
          )
        end
      end
    end

    def validate_attribute
      return unless model && attribute
      return if attribute.valid?

      attribute.errors.full_messages.each do |error|
        @errors << Magma::ActionError.new(
          message: error,
          source: @action_params.slice(:project_name, :model_name, :attribute_name)
        )
      end
    end

    def attribute
      @attribute ||= attribute_class&.new(attribute_params)
    end

    def attribute_class
      @action_params[:type] && Magma::Attribute.sti_class_from_sti_key(@action_params[:type])
    end

    def attribute_params
      fields = [:model_name, :attribute_name, :type] +
        Magma::Attribute::EDITABLE_OPTIONS

      @action_params.slice(*fields).merge(
        project_name: @project_name,
        magma_model: model
      )
    end

    def model
      return @model if defined? @model

      @model = begin
        Magma.instance.get_model(@project_name, @action_params[:model_name])
      rescue
        nil
      end
    end
  end
end
