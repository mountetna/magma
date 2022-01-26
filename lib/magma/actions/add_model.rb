require_relative "./with_date_shift_module"

class Magma
  class AddModelAction < BaseAction
    include WithDateShift

    def perform
      @model = create_model

      if !table_parent_link?
        @model.identifier(@action_params[:identifier].to_sym).save
      else
        @model.set_primary_key(:id)
      end
      project.models[@model.model_name] = @model

      if has_parent?
        @model.parent(@action_params[:parent_model_name].to_sym).save
        parent_model.send(@action_params[:parent_link_type], @model.model_name).save
      end

      true
    end

    private

    def has_parent?
      !@action_params[:parent_model_name].nil?
    end

    def create_model
      params = {
        project_name: @project_name,
        model_name: @action_params[:model_name]
      }

      params[:dictionary] = @action_params[:dictionary] if @action_params[:dictionary]
      params[:date_shift_root] = !!@action_params[:date_shift_root]

      # Here dictionary needs to be a JSON string, otherwise
      #   Sequel will try to find a column for each dictionary key.
      Magma.instance.db[:models].insert(
        params.key?(:dictionary) ?
        params.merge(dictionary: params[:dictionary].to_json) :
        params)

      project.load_model(params)
    end

    def validations
      [
          :validate_required_fields,
          :validate_parent_model,
          :validate_parent_link_type,
          :validate_model_name,
          :validate_date_shift_root_existence
      ]
    end

    def validate_required_fields
      required_fields.each do |field|
        validate_presence(field)
        validate_snake_case(field)
      end
    end

    def required_fields
      fields = [:model_name]
      fields.push(:parent_model_name, :parent_link_type) if has_parent?
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
      if @action_params[:model_name] == 'project'
        @errors << Magma::ActionError.new(
            message: "model 'project' must be the root model",
            source: @action_params.slice(:parent_model_name, :model_name)
        ) if has_parent?
        return
      end

      return if parent_model

      @errors << Magma::ActionError.new(
          message: "parent_model_name does not match a model",
          source: @action_params.slice(:parent_model_name)
      )
    end

    def validate_parent_link_type
      return unless has_parent?
      return if PARENT_LINK_TYPES.include?(@action_params[:parent_link_type])

      @errors << Magma::ActionError.new(
          message: "parent_link_type must be one of #{PARENT_LINK_TYPES.join(', ')}",
          source: @action_params.slice(:parent_model_name)
      )
    end

    def validate_model_name
      return if @action_params[:model_name] =~ /\A[a-z]*(_[a-z]+)*\Z/
      @errors << Magma::ActionError.new(
          message: "model_name must be snake_case and not contain numbers",
          source: @action_params.slice(:model_name)
      )
    end

    def validate_date_shift_root_existence
      return unless @action_params[:date_shift_root]

      # If trying to set a date_shift_root = true flag on a model,
      #   we must verify that no other model in the project
      #   is already set as the date_shift_root.
      current_root = Magma.instance.db[:models].where(project_name: @project_name, date_shift_root: true).first

      @errors << Magma::ActionError.new(
        message: "date_shift_root exists for project: #{current_root[:model_name]}",
        source: @action_params.slice(:model_name),
      ) if current_root
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
