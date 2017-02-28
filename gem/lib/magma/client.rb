require 'net/http/persistent'

class Magma
  class ClientError < StandardError
    attr_reader :status
    def initialize status
      @status = status
    end
  end
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

    def query question
      response = json_post 'query', { query: question }
      status = response.code.to_i
      if status > 300
        raise Magma::ClientError.new(status), response
      end
      return [ status, response.body ]
    end

    private

    def persistent_connection
      @http ||= Net::HTTP::Persistent.new
    end

    def json_post endpoint, params
      uri = URI::HTTPS.build host: @host, path: "/#{endpoint}"
      post = Net::HTTP::Post.new(
        uri.path,
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      )
      post.body = params.to_json
      persistent_connection.request uri, post
    end
  end
end
