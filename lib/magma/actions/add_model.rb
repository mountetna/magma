class Magma
  class AddModelAction < BaseAction
    def perform
      Magma.instance.db[:models].insert(
        project_name: @project_name,
        model_name: @action_params[:model_name]
      )

      model = project.load_model(
        project_name: @project_name,
        model_name: @action_params[:model_name]
      )

      project.models[model.model_name] = model

      if @action_params[:parent_link_type] != "table"
        model.identifier(@action_params[:identifier].to_sym).save
      end

      model.parent(@action_params[:parent_model_name].to_sym).save

      parent_model = Magma.instance.get_model(
        @project_name,
        @action_params[:parent_model_name]
      )

      parent_link = parent_model.send(
        @action_params[:parent_link_type],
        model.model_name
      )

      parent_link.save

      true
    end
  end
end
