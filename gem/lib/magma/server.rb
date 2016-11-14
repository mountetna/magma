require 'json'
require 'rack'
require 'pry'
require_relative '../magma'

class Magma
  class Server
    class Controller
      def initialize request
        @request = request
        @response = Rack::Response.new
      end

      def response
        [ 501, {}, [ "This controller is not implemented." ] ]
      end

      private

      def success msg
        @response['Content-Type'] = 'application/json'
        @response.write msg.to_json
        @response.finish
      end

      def failure status, msg
        @response.status = status
        @response.write msg.to_json
        @response.finish
      end
    end

    class Retrieve < Magma::Server::Controller
      # Okay, now we have an actual request, let's see what it looks like.
      def response
        @params = @request.env['rack.request.json']

        retrieval = Magma::Retrieval.new(
          model_name: @params["model_name"],
          record_names: @params["record_names"],
          attribute_names: @params["attributes"],
          collapse_tables: @params["collapse_tables"]
        )
        retrieval.perform
        if retrieval.success?
          success retrieval.payload.to_hash
        else
          return failure(422, errors: retrieval.errors)
        end
      end
    end

    class Update < Magma::Server::Controller
    end

    class Query < Magma::Server::Controller
    end

    class << self
      def route path, &block
        @routes ||= {}

        @routes[path] = block
      end
      attr_reader :routes
    end

    def initialize config
      Magma.instance.configure config
    end

    def call(env)
      @request = Rack::Request.new env
      dispatch
    end

    route '/retrieve' do
      # Connect to the database and get some data
      Magma::Server::Retrieve.new(@request).response
    end

    route '/update' do
      Magma::Server::Update.new(@request).response
    end

    route '/query' do
      Magma::Server::Query.new(@request).response
    end

    private

    def dispatch
      if self.class.routes.has_key? @request.path
        return instance_eval(&self.class.routes[@request.path])
      end
      [ 404, {}, ["There is no such path #{@request.path}"] ]
    end
  end

  class JsonBody
    def initialize app
      @app = app
    end
    def call(env)
      if env['CONTENT_TYPE'] =~ %r{application/json}i
        body = env['rack.input'].read
        if body =~ %r/^\s*\{/
          env.update(
            'rack.request.json' => JSON.parse(body)
          )
        end
      end
      @app.call(env)
    end
  end
  class Auth
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
      # refuse non-SSL connections
      return false if request.scheme != "http"

      true
    end
  end
end
