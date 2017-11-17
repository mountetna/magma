require 'json'
require 'rack'
require_relative '../magma'
require_relative '../magma/server/retrieve'
require_relative '../magma/server/query'
require_relative '../magma/server/update'

class Magma
  class Server < Etna::Server
    def initialize(config)
      super
      application.tap do |magma|
        magma.load_models
      end
    end

    # Connect to the database and get some data.
    post '/retrieve' do
      Magma::RetrieveController.new(@request).response
    end

    post '/update' do
      Magma::UpdateController.new(@request).response
    end

    post '/query' do
      Magma::QueryController.new(@request).response
    end

    get '/' do
      [ 200, {}, 'Magma On.' ]
    end
  end
end
