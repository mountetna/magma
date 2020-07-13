require 'sequel'
require "active_support/core_ext/class/subclasses"

require_relative 'magma/project'
require_relative 'magma/validation'
require_relative 'magma/validation_object'
require_relative 'magma/loader'
require_relative 'magma/migration'
require_relative 'magma/dictionary'
require_relative 'magma/revision'
require_relative 'magma/censor'
require_relative 'magma/commands'
require_relative 'magma/payload'
require_relative 'magma/metric'
require_relative 'magma/storage'

require 'singleton'

class Magma
  include Etna::Application
  attr_reader :db, :storage

  def get_model(project_name, model_name)
    project = get_project(project_name)
    model = project.models[model_name.to_sym] if project
    raise NameError, "Could not find Magma::Model #{project_name}::#{model_name}" unless model
    return model
  end

  def get_project(project_name)
    magma_projects[project_name.to_sym]
  end

  def magma_projects
    @magma_projects ||= {}
  end

  def setup_db
    return if @db
    @db = Sequel.connect(config(:db))
    @db.extension :connection_validator
    @db.extension :pg_json
    @db.pool.connection_validation_timeout = -1
  end

  def load_models(validate = true)
    setup_db
    setup_sequel

    @storage = Magma::Storage.setup

    config(:project_path).split(/\s+/).each do |project_dir|
      project = Magma::Project.new(project_dir: project_dir)
      magma_projects[ project.project_name ] = project
    end

    validate_models if validate
  end

  def setup_sequel
    Sequel::Model.plugin :timestamps, update_on_create: true
    Sequel::Model.require_valid_table = false
    Sequel.extension :inflector
    Sequel.extension :migration
    require_relative 'magma/attribute'
    require_relative 'magma/model'
  end

  class Magma::ValidationError < StandardError
  end

  def validate_models
    magma_projects.each do |project_name, project|
      # Check that there is a project model
      project_model = project.models.values.find {|m| m.model_name == :project}

      raise Magma::ValidationError, "There is no Project model for project #{project.project_name}" unless project_model

      project.models.each do |model_name, model|
        # Make sure the model_name is valid
        if [ :attributes, :attribute, :all, :identifier ].include?(model_name)
          raise Magma::ValidationError, "Model name #{model_name} is reserved."
        end

        # Check that tables exist
        raise Magma::ValidationError, "Missing table for #{model}." unless model.has_table?

        validate_attributes(model)

        # Check for orphan models. Make and exception for the root model.
        if(
          !model.attributes.values.any?{|att| att.is_a?(Magma::Link)} &&
          model_name != :project
        )

          raise Magma::ValidationError, "Orphan model #{model_name}." 
        end
      end
    end
  end

  def validate_attributes(model)
    model.attributes.each do |attribute_name, attribute|
      # Check that attribute has a column in the model's table
      raise Magma::ValidationError, "Missing column for #{model}##{attribute_name}." if attribute.missing_column?

      next unless attribute.respond_to?(:link_model)

      # Check reciprocal links
      link_model = attribute.link_model

      link_attribute = link_model.attributes.values.find do |attribute|
        attribute.respond_to?(:link_model) && attribute.link_model == model
      end

      raise Magma::ValidationError, "Missing reciprocal link for #{model.model_name}##{attribute_name} from #{link_model.model_name}." unless link_attribute
    end
  end

  def persist_connection
    db.extension :connection_validator
    db.pool.connection_validation_timeout = -1
  end

  def find_descendents(klass)
    ObjectSpace.each_object(Class).select do |k|
      k < klass
    end
  end

  def test?
    ENV["MAGMA_ENV"] == "test"
  end

  def server_pid
    File.read(config(:server_pidfile)).chomp.to_i
  end
end
