class Magma
  class Validation
    class Project < Magma::Validation::Model
      def initialize(model, validator)
        super
      end

      def project_name
        @project_name ||= @model.select_map( @model.identity.column_name.to_sym ).first
      end

      def self.skip?(model)
        model.model_name != :project
      end

      def validate(record_name, document)
        if project_name && record_name != project_name
          yield "Project name must match '#{project_name}'"
        end
      end
    end
  end
end
