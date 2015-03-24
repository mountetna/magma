require 'sequel'
require_relative 'magma/model'
require_relative 'magma/commands'
require 'singleton'

class Magma
  include Singleton
  def connect config
    @db = Sequel.connect( config )
  end

  def validate_models
    load_models

    # make sure your tables exist
    magma_models.each do |model|
      raise "Missing table for #{model.name}." unless @db.table_exists? model.table_name
    end
  end

  def magma_models
    @magma_models ||= find_descendents Magma::Model
  end

  def load_models
    require_relative 'models'
  end

  private
  def find_descendents klass
    ObjectSpace.each_object(Class).select do |k|
      k < klass
    end
  end
end
