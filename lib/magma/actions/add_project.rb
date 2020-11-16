class Magma

  class AddProjectAction < ComposedAction
    def perform
      # Unfortunately we cannot just run a create and catch the error due to the way ruby sequel poorly handles graceful
      # recovery of error inside transaction, which this is run inside of implicitly from parent caller.
      Magma.instance.db.run <<-SQL
DO $$
BEGIN
    IF NOT EXISTS(
        SELECT schema_name
          FROM information_schema.schemata
          WHERE schema_name = '#{@project_name}'
      )
    THEN
      EXECUTE 'CREATE SCHEMA #{@project_name}';
    END IF;
END
$$;
      SQL
      super
    end

    def validations
      [
          :validate_project_name
      ]
    end

    def validate_project_name
      return if @project_name =~ /\A[a-z][a-z0-9]*(_[a-z0-9]+)*\Z/ && !@project_name.start_with?('pg_')
      @errors << Magma::ActionError.new(
          message: "project_name must be snake_case with no spaces",
          source: @action_params.slice(:project_name)
      )
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
