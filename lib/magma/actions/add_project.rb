class Magma

  class AddProjectAction < ComposedAction
    def perform
      Magma.instance.db.run "CREATE SCHEMA IF NOT EXISTS #{@project_name}"
      super
    end

    private

    def project
      Magma.instance.get_or_load_project(@project_name)
    end

    def make_actions
      if project.models.include? :project
        []
      else
        [AddModelAction.new(@project_name, model_name: 'project', identifier: 'name')]
      end
    end
  end
end
