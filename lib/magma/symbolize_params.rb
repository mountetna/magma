class Magma
  class SymbolizeParams
    def initialize server
      @server = server
    end

    def call(env)
      env['rack.request.params'] = symbolize(env['rack.request.params'])

      @server.call(env)
    end

    private

    def symbolize(obj)
      if obj.is_a?(Hash)
        return obj.reduce({}) do |memo,(k,v)|
          memo[k.to_sym] =  symbolize(v)
          memo 
        end
      elsif obj.is_a?(Array)
        return obj.reduce([]) do |memo,v|
          memo << symbolize(v)
          memo
        end
      end
      obj
    end
  end
end
