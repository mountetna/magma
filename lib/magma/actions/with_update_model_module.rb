class Magma
  module WithUpdateModel
    def validate_model
      return if model

      @errors << Magma::ActionError.new(
        message: "Model does not exist.",
        source: @action_params.slice(:action_name, :model_name),
      )
    end

    def validate_db_model
      @errors << Magma::ActionError.new(
        message: "Model is defined in code, not in the database.",
        source: @action_params.slice(:action_name, :model_name),
      ) unless Magma.instance.db[:models].where(
        project_name: @project_name,
        model_name: @action_params[:model_name],
      ).first
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
