class Magma
  class Server
    class Controller
      def initialize request
        @request = request
        @response = Rack::Response.new
        @params = @request.env['rack.request.json']
      end

      def response
        [ 501, {}, [ "This controller is not implemented." ] ]
      end

      private

      def success content_type, msg
        @response['Content-Type'] = content_type
        @response.write msg
        @response.finish
      end

      def failure status, msg
        @response.status = status
        @response.write msg.to_json
        @response.finish
      end
    end
  end
end
