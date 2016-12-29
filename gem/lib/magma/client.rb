class Magma
  class Client
    def initialize
      config = Magma.instance.config(:client)
      raise "Magma Client configuration is missing." unless config
      @host = config[:host] 
    end

    def retrieve params
      response = json_post 'retrieve', params
      return [ response.code.to_i, response.body ]
    end

    def query params
      response = json_post 'query', params
      return [ response.code.to_i, response.body ]
    end

    private

    def json_post endpoint, params
      uri = URI::HTTPS.build host: @host, path: "/#{endpoint}"
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      http.post(
        uri.path,
        params.to_json,
        {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      )
    end
  end
end
