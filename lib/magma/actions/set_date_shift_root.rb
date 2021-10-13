class Magma
  class SetDateShiftRootAction < BaseAction
    # Action to set the date_shift_root flag on an existing model.
    # NOTE: This will only work for DB-defined models, not legacy models.
    def perform
      return false if @errors.any?

      set_date_shift_root
      true
    end

    private

    def set_date_shift_root
      Magma.instance.db.transaction do
        unset_previous_date_shift_root
        set_action_date_shift_root
      end
    end

    def unset_previous_date_shift_root
      Magma.instance.db[:models].where(
        project_name: @project_name,
        date_shift_root: true,
      ).exclude(model_name: @action_params[:model_name]).update(
        date_shift_root: false,
      )
    end

    def set_action_date_shift_root
      Magma.instance.db[:models].where(
        project_name: @project_name,
        model_name: @action_params[:model_name],
      ).update(
        date_shift_root: @action_params[:date_shift_root],
      )
    end

    def validations
      [
        :validate_model,
        :validate_db_model,
        :validate_date_shift_root,
        :validate_date_shift_root_existence,
      ]
    end

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

    def validate_date_shift_root
      @errors << Magma::ActionError.new(
        message: 'Must include :date_shift_root parameter',
        source: @action_params.slice(:action_name, :model_name)
      ) unless @action_params[:date_shift_root]
    end

    def validate_date_shift_root_existence
      return unless @action_params[:date_shift_root]

      # If trying to set a date_shift_root = true flag on a model,
      #   we must verify that no other model in the project
      #   is already set as the date_shift_root.
      @errors << Magma::ActionError.new(
        message: "date_shift_root exists for project",
        source: @action_params.slice(:model_name),
      ) if Magma.instance.db[:models].where(project_name: @project_name, date_shift_root: true).count > 0
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
