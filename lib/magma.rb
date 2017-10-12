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
  include Singleton
  # Database handle for the singleton.
  attr_reader :db, :storage
  def connect db_config
    @db = Sequel.connect( db_config )
  end

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

  def configure(opts)
    @config = opts
  end

  def config(type)
    @config[environment][type]
  end

  def environment
    (ENV['MAGMA_ENV'] || :development).to_sym
  end

  def load_models(check_tables = true)
    connect(config :db)

    if config(:storage)
      require_relative 'magma/file_uploader'
      require_relative 'magma/image_uploader'
      @storage = Magma::Storage.new
    end

    config(:project_path).split(/\s+/).each do |project_dir|
      project = Magma::Project.new(project_dir)
      magma_projects[ project.project_name ] = project
    end

    if check_tables
      magma_models.each do |model|
        raise "Missing table for #{model}." unless model.has_table?
      end
    end

    carrier_wave_init
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

  attr_reader :logger

  def logger=(logger)
    db.loggers << logger if db
    @logger = logger
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
