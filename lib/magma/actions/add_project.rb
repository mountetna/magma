class Magma

  class AddProjectAction < BaseAction
    def perform
      Magma.instance.db.run "CREATE SCHEMA IF NOT EXISTS #{@project_name}"
      inner_update_action.perform.tap { @errors.push(*inner_update_action.errors) }
    end

    private

    def project
      Magma.instance.get_or_load_project(@project_name)
    end

    def inner_update_action
      @inner_update_action ||=
          unless project.models.include? :project
            AddModelAction.new(@project_name, model_name: 'project', identifier: 'name')
          else
            NoOpAction.new(@project_name, {})
          end
    end

    def validations
      [:validate_inner_action]
    end

    def validate_inner_action
      inner_update_action.validate
      @errors.push(*inner_update_action.errors)
    end
  end
end
