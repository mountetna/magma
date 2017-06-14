require 'json'
require 'rack'
require_relative '../magma'
require_relative '../magma/server/retrieve'
require_relative '../magma/server/query'
require_relative '../magma/server/update'

class Magma
  class Server
    class << self
      def route path, &block
        @routes ||= {}

        @routes[path] = block
      end
      attr_reader :routes
    end

    def initialize config, logger
      Magma.instance.tap do |magma|
        magma.configure config

        if ENV['RACK_ENV'] == 'test'
          magma.connect(magma.config :test_database)
        else
          magma.load_models
        end

        magma.persist_connection

        magma.db.loggers << logger
      end
    end

    def call(env)
      @request = Rack::Request.new env

      if self.class.routes.has_key? @request.path
        return instance_eval(&self.class.routes[@request.path])
      end

      [ 404, {}, ["There is no such path #{@request.path}"] ]
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

    route '/' do
      [ 200, {}, "::magma::" ]
    end

    private
  end
end
