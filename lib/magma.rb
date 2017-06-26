require 'sequel'
require_relative 'magma/validation'
require_relative 'magma/loader'
require_relative 'magma/migration'
require_relative 'magma/attribute'
require_relative 'magma/model'
require_relative 'magma/revision'
require_relative 'magma/commands'
require_relative 'magma/payload'
require_relative 'magma/metric'
require 'singleton'

class Magma
  include Singleton
  attr_reader :db
  def connect db_config
    @db = Sequel.connect( db_config )
  end

  def get_model name
    begin
      model = Kernel.const_get name.to_s.camel_case.to_sym
      raise NameError unless model < Magma::Model
      model
    rescue NameError => e
      raise NameError, "Could not find Magma::Model #{name}"
    end
  end

  def magma_models
    @magma_models ||= find_descendents Magma::Model
  end

  def configure opts
    @config = opts
  end

  def config type
    @config[environment][type]
  end

  def environment
    (ENV["MAGMA_ENV"] || :development).to_sym
  end

  def load_models check_tables=true
    connect(config :db)
    config(:project_path).split(/\s+/).each do |model_dir|
      Dir.glob(File.join(File.dirname(__FILE__), "../#{model_dir}/models", '**', '*.rb'), &method(:require))
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

  def find_descendents klass
    ObjectSpace.each_object(Class).select do |k|
      k < klass
    end
  end

  private

  def carrier_wave_init
    opts = config(:storage)
    return unless opts
    require_relative 'magma/document'
    require_relative 'magma/image'
    CarrierWave.tmp_path = '/tmp'
    CarrierWave.configure do |config|
      config.fog_credentials = opts[:credentials]
      config.fog_directory = opts[:directory]
      config.fog_public = false
      config.fog_attributes = { 'Cache-Control' => "max-age=#{365 * 86400}" }
    end
  end
end
