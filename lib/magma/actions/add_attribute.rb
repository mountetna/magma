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
      return false unless model

      if attribute_already_exists?
        @errors << Magma::ActionError.new(
          message: 'Attribute already exists',
          source: @action_params.slice(:project_name, :model_name, :attribute_name)
        )
      end

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

    def attribute_params
      fields = [:model_name, :attribute_name, :type] +
        Magma::Attribute::EDITABLE_OPTIONS

      @action_params.slice(*fields).merge(project_name: @project_name)
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
      pid = File.read("tmp/pids/puma.pid").chomp.to_i
      Process.kill("USR2", pid)
    end

    def attribute_already_exists?
      model.attributes.keys.include?(@action_params[:attribute_name].to_sym)
    end

    def model
      @model ||= begin
        Magma.instance.get_model(@project_name, @action_params[:model_name])
      rescue => e
        @errors << Magma::ActionError.new(
          message: 'Model does not exist',
          source: @action_params.slice(:action_name, :model_name),
          reason: e
        )

        nil
      end
    end
  end
end
