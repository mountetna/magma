require 'sequel'
require_relative 'magma/project'
require_relative 'magma/validation'
require_relative 'magma/loader'
require_relative 'magma/migration'
require_relative 'magma/attribute'
require_relative 'magma/model'
require_relative 'magma/revision'
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
    @db = Sequel.connect(config(:db))
    @db.extension :connection_validator
    @db.pool.connection_validation_timeout = -1
  end

  def load_models(validate = true)
    setup_db

    if config(:storage)
      require_relative 'magma/file_uploader'
      require_relative 'magma/image_uploader'
      @storage = Magma::Storage.new
    end

    config(:project_path).split(/\s+/).each do |project_dir|
      project = Magma::Project.new(project_dir)
      magma_projects[ project.project_name ] = project
    end

    validate_models if validate

    carrier_wave_init
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

        # Check reciprocal links
        model.attributes.each do |att_name, attribute|
          next unless attribute.respond_to?(:link_model)
          link_model = attribute.link_model
          link_attribute = link_model.attributes.values.find do |attribute|
            attribute.respond_to?(:link_model) && attribute.link_model == model
          end
          raise Magma::ValidationError, "Missing reciprocal link for #{model_name}##{att_name} from #{link_model.model_name}." unless link_attribute
        end

        # Check for orphan models
        raise Magma::ValidationError, "Orphan model #{model_name}." unless model.attributes.values.any?{|att| att.is_a?(Magma::Link)}
      end
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

  private

  def carrier_wave_init
    opts = config(:storage)
    return unless opts
    #CarrierWave.tmp_path = '/tmp'
    CarrierWave.configure do |config|
      config.fog_credentials = opts[:credentials]
      config.fog_directory = opts[:directory]
      config.fog_public = false
      config.fog_attributes = {'Cache-Control'=> "max-age=#{365 * 86400}"}
    end
  end
end
