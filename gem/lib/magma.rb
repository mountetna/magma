require 'sequel'
require_relative 'magma/attribute'
require_relative 'magma/model'
require_relative 'magma/migration'
require_relative 'magma/document'
require_relative 'magma/commands'
require 'singleton'

class Magma
  include Singleton
  attr_reader :db
  def connect config
    @db = Sequel.connect( config )
  end

  def validate_models
    load_models

    # make sure your tables exist
    magma_models.each do |model|
      model.validate
    end
  end

  def get_model name
    Kernel.const_get name.to_s.camel_case.to_sym
  end

  def magma_models
    @magma_models ||= find_descendents Magma::Model
  end

  def load_models
    require_relative 'models'
  end

  def configure opts
    connect opts[:database]
    validate_models
    carrier_wave_config opts[:storage]
  end

  private
  def find_descendents klass
    ObjectSpace.each_object(Class).select do |k|
      k < klass
    end
  end

  def carrier_wave_config opts
    return unless opts
    CarrierWave.configure do |config|
      config.fog_credentials = opts[:credentials]
      config.fog_directory = opts[:directory]
      config.fog_public = false
      config.fog_attributes = { 'Cache-Control' => "max-age=#{365 * 86400}" }
    end
  end
end
