require_relative 'action_error'

class Magma
  class AddAttributeAction
    def initialize(project_name, action_params = {})
      @project_name = project_name
      @action_params = action_params
      @errors = []
    end

    def perform
      if attribute = create_attribute
        model.load_attributes([attribute])
        update_model_table
      end

      @errors.empty?
    end

    def validate
      validate_project && validate_model && validate_attribute_name_unique && validate_attribute
      @errors.empty?
    end

    def errors
      @errors.map(&:to_h)
    end

    private

    def create_attribute
      attribute_class = Magma::Attribute.
        sti_class_from_sti_key(@action_params[:type])

      attribute_class.create(attribute_params)
    rescue Sequel::ValidationFailed => e
      @errors << Magma::ActionError.new(
        message: 'Create attribute failed',
        source: @action_params.slice(:project_name, :model_name),
        reason: e
      )

      nil
    end

    def update_model_table
      migration = eval("
        Sequel.migration do
          up do
            #{model.migration.to_s}
          end
        end
      ")

      migration.apply(Magma.instance.db, :up)
      restart_server
    end

    def restart_server
      return if Magma.instance.test?
      Process.kill("USR2", Magma.instance.server_pid)
    end

    def validate_project
      return true if Magma.instance.get_project(@project_name)

      @errors << Magma::ActionError.new(
        message: 'Project does not exist',
        source: @project_name
      )

      false
    end

    def validate_model
      return true if model

      @errors << Magma::ActionError.new(
        message: 'Model does not exist',
        source: @action_params.slice(:action_name, :model_name)
      )

      false
    end

    def validate_attribute_name_unique
      return true if !model.has_attribute?(attribute.attribute_name)

      @errors << Magma::ActionError.new(
        message: "attribute_name already exists on #{model.name}",
        source: @action_params.slice(:project_name, :model_name, :attribute_name)
      )

      false
    end

    def validate_attribute
      return true if attribute.valid?

      attribute.errors.full_messages.each do |error|
        @errors << Magma::ActionError.new(
          message: error,
          source: @action_params.slice(:project_name, :model_name, :attribute_name)
        )
      end

      false
    end

    def attribute
      @attribute ||= attribute_class.new(attribute_params)
    end

    def attribute_class
      Magma::Attribute.sti_class_from_sti_key(@action_params[:type])
    end

    def attribute_params
      fields = [:model_name, :attribute_name, :type] +
        Magma::Attribute::EDITABLE_OPTIONS

      @action_params.slice(*fields).merge(
        project_name: @project_name,
        magma_model: model
      )
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
