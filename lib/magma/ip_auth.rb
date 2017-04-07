class Magma
  class IpAuth
    def initialize server
      @server = server
    end

    def call(env)
      request = Rack::Request.new(env)
      # this guy will authenticate the entire request
      # or bail if it fails

      if valid_request?(request)
        @server.call(env)
      else
        [ 401, {}, [ "Unauthorized" ] ]
      end
    end

    def valid_request? request
      request.ip == '127.0.0.1'
    end
  end
end
