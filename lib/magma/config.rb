# This is just a wrapper for the config file that makes it accessible
class Magma
  class Config
    def initialize config
      @config = config
    end

    def method_missing sym, *args, &block
      if @config.has_key? sym
        return @config[sym]
      end
      super
    end
  end
end
