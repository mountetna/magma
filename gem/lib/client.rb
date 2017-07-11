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

    # This 'retrieve' end point resolves to a standard SQL query that give us
    # back sets of data. It is to be used to for querying general record sets.
    def retrieve(token, project_name, params)
      params[:token] = token
      params[:project_name] = project_name
      response = json_post('retrieve', params)
      status = response.code.to_i

      # If something went wrong with the magma server...
      if status >= 500
        raise_err(status, {errors: ['A Magma server error occurred.']})
      elsif status >= 400
        raise_err(status, errors: parse_err(response))
      end

      # Everything worked out great.
      return [status, response.body]
    end

    # This 'query' end point is used to fetch a very specific peice of data from
    # the database using what we have termed 'Manifests'. A 'Manifest' (in
    # short) is a graph query that traverses the database and extracts a very 
    # particular peice of data.
    def query(token, project_name, question)
      opts = {token: token, project_name: project_name, query: question}
      response = json_post('query', opts)
      status = response.code.to_i

      # If something went wrong with the magma server...
      if status >= 500
        raise_err(status, {errors: ['A Magma server error occurred.']})
      elsif status >= 400
        raise_err(status, {query: question, errors: parse_err(response)})
      end

      # Everything worked out great.
      return [status, response.body]
    end

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
        raise_err(status, {errors: ['A Magma server error occurred.']})
      elsif status >= 400
        raise_err(status, {update: revisions, errors: parse_err(response)})
      end

      # Everything worked out great.
      return [status, response.body]
    end

    private

    def json_post(endpoint, params)
      post(endpoint, 'application/json', params.to_json)
    end

    def multipart_post(endpoint, content)
      begin
        uri = URI("#{@host}/#{endpoint}")
        multipart = Net::HTTP::Post::Multipart.new(uri.path, content)
        persistent_connection.request(uri, multipart)
      rescue
        raise_err(500, {errors: ['There was a Magma connection error.']})
      end
    end

    def post(endpoint, content_type, body)
      begin
        uri = URI("#{@host}/#{endpoint}")
        post = Net::HTTP::Post.new(
          uri.path,
          'Content-Type'=> content_type,
          'Accept'=> 'application/json'
        )
        post.body = body
        persistent_connection.request(uri, post)
      rescue
        raise_err(500, {errors: ['There was a Magma connection error.']})
      end
    end

    def persistent_connection
      @http ||= begin
        http = Net::HTTP::Persistent.new
        http.read_timeout = 3600
        http
      end
    end

    def parse_err(response)
      JSON.parse(response.body)['errors']
    end

    def raise_err(status, body)
      raise Magma::ClientError.new(status, body)
    end
  end
end
