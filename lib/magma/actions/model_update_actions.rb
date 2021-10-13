require_relative 'base_action'
require_relative 'update_attribute'
require_relative 'add_attribute'
require_relative 'add_link'
require_relative 'add_model'
require_relative 'rename_attribute'
require_relative 'add_project'
require_relative 'add_dictionary'
require_relative 'set_date_shift_root'
require 'rollbar'

class Magma
  class ModelUpdateActions
    class FailedActionError < StandardError; end

    def self.build(project_name, actions_list, user, model_versions = nil)
      new(project_name, actions_list, user, model_versions)
    end

    def perform
      return false unless valid?

      db.transaction do
        raise FailedActionError unless @actions.all?(&:perform)

        unless @model_versions.nil?
          target_models.uniq { |v| v.model_name }.each do |model|
            version = @model_versions[model.model_name.to_s]
            if !update_version(model.model_name, version)
              @errors << Magma::ActionError.new(
                  message: "Concurrent modification",
                  source: [@project_name, 'version', version],
              )

              raise "Concurrent modification of #{@project_name}"
            end
          end
        end

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

    def target_models
      @target_models ||= @actions.flat_map(&:target_models)
    end

    def errors
      @errors.map(&:to_h) + @actions.flat_map(&:errors)
    end

    def valid?
      validate_project

      # Note -- this is the 'soft' version of the version validation that tries to provide useful user feedback.
      # The 'hard' version of the version validation is the update_version which will reject one transaction
      # in the case of concurrent modifications.
      validate_model_versions
      @errors.empty? && @actions.all?(&:validate)
    end

    def validate_model_versions
      return if @model_versions.nil?

      target_models.each do |model|
        unless @model_versions.include?(model.model_name.to_s)
          @errors << Magma::ActionError.new(
              message: "Update for #{model.model_name} found, but no version provided in model_versions.",
              source: [@project_name, @model_versions, model.model_name],
          )
        end
      end

      @model_versions.each do |model_name, version|
        model = db[:models].where(model_name: model_name.to_s, project_name: @project_name.to_s).first
        if !model.nil? && model[:version] > version
          @errors << Magma::ActionError.new(
              message: "Update for #{model_name} out of date. Current version is #{model[:version]}",
              source: [@project_name, model_name],
          )
        end
      end
    end

    private

    def update_version(model_name, old_version)
      rows_updated = db[:models].where(
          project_name: @project_name.to_s,
          model_name: model_name.to_s,
      ).where(Sequel.lit('version <= ?', old_version)).update(version: old_version + 1)
      rows_updated == 1
    end

    def db
      Magma.instance.db
    end

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

      sequel_migration.apply(db, :up)
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

    def initialize(project_name, actions_list, user, model_versions = nil)
      @project = Magma.instance.get_or_load_project(project_name)
      @project_name = project_name
      @model_versions = model_versions
      @user = user
      @errors = []
      @actions = []

      actions_list.each do |action_params|
        action_class = "Magma::#{action_params[:action_name].classify}Action".safe_constantize

        if action_class
          action_params.update({user: @user}) if action_params[:action_name] == 'add_project'

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
