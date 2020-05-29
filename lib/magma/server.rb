require 'json'
require 'rack'
require_relative '../magma'
require_relative '../magma/server/retrieve'
require_relative '../magma/server/query'
require_relative '../magma/server/update'

class Magma
  class Server < Etna::Server
    def initialize
      super
      application.tap do |magma|
        magma.load_models
      end
    end

    # Connect to the database and get some data.
    post '/retrieve', as: :retrieve, action: 'retrieve#action', auth: { user: { can_view?: :project_name } }

    post '/query', as: :query, action: 'query#action', auth: { user: { can_view?: :project_name } }

    post '/update', as: :update, action: 'update#action', auth: { user: { can_edit?: :project_name } } 

    get '/' do
      [ 200, {}, [ 'Magma is available.' ] ]
    end
  end
end
