require_relative 'base_action'
require_relative 'update_attribute'
require_relative 'add_attribute'
require_relative 'add_link'
require_relative 'add_model'
require_relative 'rename_attribute'
require_relative 'add_project'
require 'rollbar'

class Magma
  class ModelUpdateActions
    class FailedActionError < StandardError; end

    def self.build(project_name, actions_list, user)
      new(project_name, actions_list, user)
    end

    def perform
      return false unless valid?

      Magma.instance.db.transaction do
        raise FailedActionError unless @actions.all?(&:perform)
        update_model_tables
        true
      end
    rescue => e
      restart_server

      Rollbar.error(e)

      if @errors.empty?
        @errors << Magma::ActionError.new(
          message: "Unexpected error",
          source: nil,
          reason: e
        )
      end

      false
    end

    def errors
      @errors.map(&:to_h) + @actions.flat_map(&:errors)
    end

    def valid?
      validate_project
      @errors.empty? && @actions.all?(&:validate)
    end

    private

    def update_model_tables
      migrations = @project.migrations
      return if migrations.all?(&:empty?)

      sequel_migration = eval("
        Sequel.migration do
          up do
            #{migrations.map(&:to_s).join("\n")}
          end
        end
      ")

      sequel_migration.apply(Magma.instance.db, :up)
      restart_server
    end

    def restart_server
      return if Magma.instance.test?
      Process.kill("USR2", Magma.instance.server_pid)
    end

    def validate_project
      return if @project

      @errors << Magma::ActionError.new(
        message: 'Project does not exist',
        source: @project_name
      )
    end

    def initialize(project_name, actions_list, user)
      @project = Magma.instance.get_or_load_project(project_name)
      @user = user
      @errors = []
      @actions = []

      actions_list.each do |action_params|
        action_class = "Magma::#{action_params[:action_name].classify}Action".safe_constantize

        if action_class
          action_params.update!({user: @user}) if action_params[:action_name] == 'add_project'

          @actions << action_class.new(
            project_name,
            action_params)
        else
          @errors << Magma::ActionError.new(
            message: "Invalid action type",
            source: action_params[:action_name]
          )
        end
      end
    end
  end
end
