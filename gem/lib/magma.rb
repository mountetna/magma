require_relative 'client'
require 'singleton'

class Magma
  include Singleton
  def configure opts
    @config = opts
  end

  def config type
    @config[type]
  end
end
