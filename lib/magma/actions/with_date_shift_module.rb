class Magma
  module WithDateShift
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
  end
end
