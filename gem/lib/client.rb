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
    def retrieve(token, project_name, params, &block)
      params[:token] = token
      params[:project_name] = project_name
      json_post(:retrieve, params, &block)
    end

    # This 'query' end point is used to fetch data by graph query
    # See question.rb for more detail
    def query(token, project_name, question, &block)
      params = {token: token, project_name: project_name, query: question}
      json_post(:query, params, { 500 => params, 400 => params }, &block)
    end

    # Post revisions to Magma records
    # { model_name: { record_name: { attribute1: 1, attribute2: 2 } } } }
    # data can also be a File or IO stream
    def update(token, project_name, revisions, &block)
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

      content << [ 'token', token ]
      content << [ 'project_name', project_name ]

      multipart_post(:update, content, { 400 => { update: revisions } }, &block)
    end

    private

    def persistent_connection
      @http ||= begin
                  http = Net::HTTP::Persistent.new
                  http.read_timeout = 3600
                  http
                end
    end

    def json_post(endpoint, params, status_errors={}, &block)
      post(endpoint, "application/json", params.to_json, status_errors, &block)
    end

    def multipart_post(endpoint, content, status_errors={}, &block)
      uri = URI("#{@host}/#{endpoint}")
      multipart = Net::HTTP::Post::Multipart.new uri.path, content

      request(uri, multipart, status_errors, &block)
    end

    def post(endpoint, content_type, body, status_errors, &block)
      uri = URI("#{@host}/#{endpoint}")
      post = Net::HTTP::Post.new(
        uri.path,
        'Content-Type'=> content_type,
        'Accept'=> 'application/json'
      )
      post.body = body
      request(uri, post, status_errors, &block)
    end

    def status_check(response, status_errors)
      status = response.code.to_i
      if status >= 500
        raise Magma::ClientError.new(status, (status_errors[500] || {}).merge(errors: [ "A Magma server error occured." ]))
      elsif status >= 400
        raise Magma::ClientError.new(status, (status_errors[400] || {}).merge(errors: JSON.parse(response.body)["errors"]))
      end
    end

    def request(uri, data, status_errors, &block)
      if block_given?
        persistent_connection.request(uri, data) do |response|
          status_check(response, status_errors)
          yield response
        end
      else
        response = persistent_connection.request(uri, data)
        status_check(response, status_errors)
        return response
      end
    end
  end
end
