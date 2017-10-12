require 'json'
require 'rack'
require_relative '../magma'
require_relative '../magma/server/retrieve'
require_relative '../magma/server/query'
require_relative '../magma/server/update'

class Magma
  class Server
    class << self
      attr_reader :routes

      def route(path, &block)
        @routes ||= {}

        @routes[path] = block
      end
    end

    def initialize(config, logger)
      Magma.instance.tap do |magma|
        magma.configure(config)
        magma.load_projects
        magma.persist_connection
        magma.logger = logger
      end
    end

    def call(env)
      @request = Rack::Request.new env

      if self.class.routes.has_key? @request.path
        return instance_eval(&self.class.routes[@request.path])
      end

      [404, {}, ["There is no such path #{@request.path}"]]
    end

    # Connect to the database and get some data.
    route '/retrieve' do
      Magma::Server::Retrieve.new(@request).response
    end

    route '/update' do
      Magma::Server::Update.new(@request).response
    end

    route '/query' do
      Magma::Server::Query.new(@request).response
    end

    route '/' do
      response = Rack::Response.new
      response.write('Magma On.')
      response.status = 200
      response.finish
    end
  end
end
