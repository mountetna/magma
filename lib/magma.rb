require 'sequel'
require_relative 'magma/attribute'
require_relative 'magma/model'
require_relative 'magma/migration'
require_relative 'magma/revision'
require_relative 'magma/document'
require_relative 'magma/image'
require_relative 'magma/commands'
require_relative 'magma/loader'
require_relative 'magma/payload'
require_relative 'magma/metric'
require 'singleton'

class Magma
  include Singleton
  attr_reader :db
  def connect config
    @db = Sequel.connect( config )
  end

  def get_model name
    Kernel.const_get name.to_s.camel_case.to_sym
  end

  def magma_models
    @magma_models ||= find_descendents Magma::Model
  end

  def configure opts
    @config = opts
  end

  def config type
    @config[type]
  end

  def load_models
    connect(config :database)
    require_relative 'models'
    magma_models.each do |model|
      model.validate
    end
    carrier_wave_init
  end

  def persist_connection
    db.extension :connection_validator
    db.pool.connection_validation_timeout = -1
  end

  private

  def carrier_wave_init
    opts = config(:storage)
    return unless opts
    CarrierWave.tmp_path = '/tmp'
    CarrierWave.configure do |config|
      config.fog_credentials = opts[:credentials]
      config.fog_directory = opts[:directory]
      config.fog_public = false
      config.fog_attributes = { 'Cache-Control' => "max-age=#{365 * 86400}" }
    end
  end

  def find_descendents klass
    ObjectSpace.each_object(Class).select do |k|
      k < klass
    end
  end
end
