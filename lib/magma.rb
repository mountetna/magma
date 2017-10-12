require 'sequel'
require_relative 'magma/validator'
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
    model_class_name = model_name.to_s.camel_case
    project_class_name = project_name.to_s.camel_case
    begin
      model = Kernel.const_get(project_class_name).const_get(model_class_name)
      raise NameError unless model < Magma::Model
      return model
    rescue NameError => e
      err_txt = "Could not find Magma::Model #{project_class_name}::#{model_class_name}"
      raise(NameError, err_txt)
    end
  end

  def magma_models
    @magma_models ||= find_descendents(Magma::Model)
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

  # Load the files specific to projects such as their data models, validators, 
  # loaders, and metrics.
  def load_projects(check_tables = true)
    connect(config :db)

    if config(:storage)
      require_relative 'magma/file_uploader'
      require_relative 'magma/image_uploader'
      @storage = Magma::Storage.new
    end

    # Extract the liste project paths from the config file and loop over them.
    config(:project_path).split(/\s+/).each do |project_dir|

      dir_nm = File.dirname(__FILE__) # Current working directory name.

      # Look in each project path for the 'requirements.rb' file. This file
      # should list out what models and items are to be included at Magma
      # start up.
      base_file = File.join(dir_nm, '..', project_dir, 'requirements.rb')

      # If the 'requirements.rb' file exists then load that file. Otherwise load
      # the items from the sub folders.
      if File.exists?(base_file)
        require base_file 
      else
        ['validators', 'models', 'loaders', 'metrics'].each do |folder_name|
          args = [dir_nm, '..', project_dir, folder_name, '**', '*.rb']
          Dir.glob(File.join(*args), &method(:require))
        end
      end
    end

    # Check that the loaded models have matching tables in postgres.
    if check_tables
      magma_models.each do |model|
        raise "Missing table for #{model}." unless model.has_table?
      end
    end

    # Start up Carrierwave, which hooks into S3, which houses our large files.
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
