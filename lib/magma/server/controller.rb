class Magma
  class Server
    class Controller
      def initialize(request)
        @request = request
        @response = Rack::Response.new
        @params = @request.env['rack.request.params']
        @user = @request['user_info']
        @errors = []
        @logger = @request.env['rack.errors']
        @project_name = @params[:project_name]
      end

      def log(line)
        @logger.write "#{Time.now.strftime("%d/%b/%Y %H:%M:%S")} #{line}\n"
      end

      def response
        [501, {}, ['This controller is not implemented.']]
      end

      private

      def success(content_type, msg)
        @response['Content-Type'] = content_type
        @response.write(msg)
        @response.finish
      end

      def failure(status, msg)
        @response.status = status
        @response.write(msg.to_json)
        @response.finish
      end

      def success?
        @errors.empty?
      end

      def error(msg)
        if msg.is_a?(Array)
          @errors.concat(msg)
        else
          @errors.push(msg)
        end
      end
    end
  end
end
