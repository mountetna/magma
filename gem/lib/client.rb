require 'net/http/persistent'
require 'net/http/post/multipart'
require 'singleton'

class Magma
  class ClientError < StandardError
    attr_reader :status, :body
    def initialize status, body
      @status = status
      @body = body
    end
  end

  class Client
    include Singleton
    def initialize
      @host = Magma.instance.config(:host)
      raise "Magma configuration is missing host entry." unless @host
    end

    def retrieve params
      response = json_post 'retrieve', params
      status = response.code.to_i
      if status > 300
        raise Magma::ClientError.new(status, errors: errors(response))
      end
      return [ response.code.to_i, response.body ]
    end

    def query question
      response = json_post 'query', { query: question }
      status = response.code.to_i
      if status > 300
        raise Magma::ClientError.new(status, query: question, errors: errors(response))
      end
      return [ status, response.body ]
    end

    def update revisions
      content = []

      # we need to store revision data in a multipart/form-data object.
      # we will construct a key like this:
      # revisions['model_name']['record_name']['attribute_name']
      revisions.each do |model_name, model_revisions|
        model_revisions.each do |record_name, revision|
          revision.each do |att_name, value|
            content << [
              "revisions[#{ model_name }][#{ record_name }][#{ att_name }]#{ value.is_a?(Array) ? "[]" : nil }",
              value.respond_to?(:read) ? UploadIO.new(value, 'application/octet-stream') : value
            ]
          end
        end
      end
      response = multipart_post 'update', content
      status = response.code.to_i
      if status > 300
        raise Magma::ClientError.new(status, update: revisions, errors: errors(response))
      end
      return [ status, response.body ]
    end

    private

    def persistent_connection
      @http ||= begin
                  http = Net::HTTP::Persistent.new
                  http.read_timeout = 3600
                  http
                end
    end

    def json_post endpoint, params
      post endpoint, "application/json", params.to_json
    end

    def multipart_post endpoint, content
      uri = URI("#{@host}/#{endpoint}")
      multipart = Net::HTTP::Post::Multipart.new uri.path, content
      persistent_connection.request uri, multipart
    end

    def post endpoint, content_type, body
      uri = URI("#{@host}/#{endpoint}")
      post = Net::HTTP::Post.new(
        uri.path,
        "Content-Type" => content_type,
        "Accept" => "application/json"
      )
      post.body = body
      persistent_connection.request uri, post
    end

    def errors response
      JSON.parse(response.body)["errors"]
    end
  end
end
