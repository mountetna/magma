class Magma
  class AddModelAction < BaseAction
    def perform
      @model = create_model

      if !table_parent_link?
        @model.identifier(@action_params[:identifier].to_sym).save
      end

      @model.parent(@action_params[:parent_model_name].to_sym).save

      project.models[@model.model_name] = @model

      parent_model.
        send(@action_params[:parent_link_type], @model.model_name).
        save

      true
    end

    def rollback
      parent_model.attributes.delete(@model.model_name)
      project.unload_model(@model.model_name)
    end

    private

    def create_model
      Magma.instance.db[:models].insert(
        project_name: @project_name,
        model_name: @action_params[:model_name]
      )

      project.load_model(
        project_name: @project_name,
        model_name: @action_params[:model_name]
      )
    end

    def validations
      [
        :validate_required_fields,
        :validate_parent_model,
        :validate_parent_link_type
      ]
    end

    def validate_required_fields
      required_fields.each do |field|
        validate_presence(field)
        validate_snake_case(field)
      end
    end

    def required_fields
      fields = [:model_name, :parent_model_name, :parent_link_type]
      fields << :identifier unless table_parent_link?
      fields
    end

    def validate_presence(field)
      return if @action_params[field] && @action_params[field] != ""

      @errors << Magma::ActionError.new(
        message: "#{field} is required",
        source: @action_params.slice(field)
      )
    end

    def validate_snake_case(field)
      return if @action_params[field]&.snake_case == @action_params[field]

      @errors << Magma::ActionError.new(
        message: "#{field} must be snake_case",
        source: @action_params.slice(field)
      )
    end

    def validate_parent_model
      return if parent_model

      @errors << Magma::ActionError.new(
        message: "parent_model_name does not match a model",
        source: @action_params.slice(:parent_model_name)
      )
    end

    def validate_parent_link_type
      return if PARENT_LINK_TYPES.include?(@action_params[:parent_link_type])

      @errors << Magma::ActionError.new(
        message: "parent_link_type must be one of #{PARENT_LINK_TYPES.join(', ')}",
        source: @action_params.slice(:parent_model_name)
      )
    end

    def table_parent_link?
      @action_params[:parent_link_type] == "table"
    end

    PARENT_LINK_TYPES = ["child", "collection", "table"]

    def parent_model
      @parent_model ||= begin
        Magma.instance.get_model(
          @project_name,
          @action_params[:parent_model_name]
        )
      rescue NameError
        nil
      end
    end
  end
end
