require 'net/http/persistent'
require 'net/http/post/multipart'
require 'singleton'

class Magma
  class ClientError < StandardError
    attr_reader :status, :body

    def initialize(status, body)
      @status = status
      @body = body
    end
  end

  class Client
    include Singleton

    def initialize
      @host = Magma.instance.config(:host)
      raise 'Magma configuration is missing host entry.' unless @host
    end

    # This endpoint returns models and records by name:
    # e.g. params:
    # {
    #   model_name: "model_one", # or "all"
    #   record_names: [ "rn1", "rn2" ], # or "all",
    #   attribute_names:  "all"
    # }
    def retrieve(token, project_name, params)
      params[:token] = token
      params[:project_name] = project_name
      response = json_post('retrieve', params)
      status = response.code.to_i

      # If something went wrong with the magma server...
      if status >= 500
        raise Magma::ClientError.new(status, {errors: ['A Magma server error occurred.']})
      elsif status >= 400
        raise Magma::ClientError.new(status, errors: parse_error(response))
      end

      # Everything worked out great.
      return [status, response.body]
    end

    # This 'query' end point is used to fetch data by graph query
    # See question.rb for more detail
    def query(token, project_name, question)
      opts = {token: token, project_name: project_name, query: question}
      response = json_post('query', opts)
      status = response.code.to_i

      # If something went wrong with the magma server...
      if status >= 500
        raise Magma::ClientError.new(status, {errors: ['A Magma server error occurred.']})
      elsif status >= 400
        raise Magma::ClientError.new(status, {query: question, errors: parse_error(response)})
      end

      # Everything worked out great.
      return [status, response.body]
    end

    # Post revisions to Magma records
    # { model_name: { record_name: { attribute1: 1, attribute2: 2 } } } }
    # data can also be a File or IO stream
    def update(revisions)
      content = []

      # We need to store revision data in a multipart/form-data object.
      # We will construct a key like this:
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

      # Send the update data.
      response = multipart_post('update', content)
      status = response.code.to_i

      # If something went wrong with the magma server...
      if status >= 500
        raise Magma::ClientError.new(status, {errors: ['A Magma server error occurred.']})
      elsif status >= 400
        raise Magma::ClientError.new(status, {update: revisions, errors: parse_error(response)})
      end

      # Everything worked out great.
      return [status, response.body]
    end

    private

    def json_post(endpoint, params)
      post(endpoint, 'application/json', params.to_json)
    end

    def multipart_post(endpoint, content)
      uri = URI("#{@host}/#{endpoint}")
      multipart = Net::HTTP::Post::Multipart.new(uri.path, content)
      persistent_connection.request(uri, multipart)
    end

    def post(endpoint, content_type, body)
      uri = URI("#{@host}/#{endpoint}")
      post = Net::HTTP::Post.new(
        uri.path,
        'Content-Type'=> content_type,
        'Accept'=> 'application/json'
      )
      post.body = body
      persistent_connection.request(uri, post)
    end

    def persistent_connection
      @http ||= begin
        http = Net::HTTP::Persistent.new
        http.read_timeout = 3600
        http
      end
    end

    def parse_error(response)
      JSON.parse(response.body)['errors']
    end
  end
end
