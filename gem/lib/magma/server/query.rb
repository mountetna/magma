require_relative 'controller'
require_relative '../query/data_table'

class Magma
  class Server
    class Query < Magma::Server::Controller
      def response
        @payload = Magma::Payload.new
        (@params["queries"] || []).each do |query_json|
          @payload.add_data(Magma::DataTable.new(query_json))
        end

        success @payload.to_hash
      end
    end
  end
end
