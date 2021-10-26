require_relative "./with_date_shift_module"
require_relative "./with_update_model_module"

class Magma
  class SetDateShiftRootAction < BaseAction
    include WithDateShift
    include WithUpdateModel

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
        :validate_not_table_model,
      ]
    end

    def validate_date_shift_root
      @errors << Magma::ActionError.new(
        message: "Must include :date_shift_root parameter",
        source: @action_params.slice(:action_name, :model_name),
      ) unless @action_params.key?(:date_shift_root)
    end

    def validate_not_table_model
      return if !model

      return unless model.parent_model.attributes[model.model_name].is_a?(Magma::TableAttribute)

      @errors << Magma::ActionError.new(
        message: "Cannot set :date_shift_root on a Table.",
        source: @action_params.slice(:action_name, :model_name),
      )
    end
  end
end
