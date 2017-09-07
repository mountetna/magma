# All we do here is to check that the user has some permission on a project. If 
# the user does have a permission we let them pass. If not, then we kick the 
# user out. We do not decide what the user can and cannot do at this level.
# Here, we only check that a permission is existant.

require 'net/http'

class Magma
  class AuthError < StandardError
    attr_reader :status, :body

    def initialize(status, body)
      @status = status
      @body = body
    end

    def to_json
      { errors: [ @body ] }.to_json
    end
  end

  class Auth
    def initialize(app, config)
      @app = app
      @config = config
    end

    def call(env)
      # Don't check authentication in the test environment - this might not be the right move
      return @app.call(env) if ENV["MAGMA_ENV"] == "test"

      @params = env['rack.request.params']

      raise Magma::AuthError.new(422, 'No token.') if @params[:token].nil?
      raise Magma::AuthError.new(422, 'No project_name.') if @params[:project_name].nil?

      # Make the request to Janus.
      response = make_request(
        Magma.instance.config(:janus_addr)+'/check',
        token: @params[:token],
        app_key: Magma.instance.config(:app_key)
      )

      user_info = JSON.parse(response.body, symbolize_names: true)

      raise Magma::AuthError.new(422, 'Invalid project.') unless has_project_permission?(user_info)

      # Set the user's permissions on the 'env' object, and carry on!
      env.update('user_info'=> user_info)

      # Carry on!
      @app.call(env)
    rescue Magma::AuthError => err
      return Rack::Response.new(err.to_json, err.status)
    end


    # Make a request to Janus for the user permissions.
    def make_request(url, data)
      uri = URI.parse(url)
      https_conn = Net::HTTP.new(uri.host, uri.port)
      https_conn.use_ssl = true
      https_conn.verify_mode = OpenSSL::SSL::VERIFY_PEER
      https_conn.open_timeout = 20
      https_conn.read_timeout = 20

      request = Net::HTTP::Post.new(uri.path)
      request.set_form_data(data)

      response = https_conn.request(request)
      status = response.code.to_i

      # If something went wrong with the janus server...
      raise Magma::AuthError.new(422, 'Invalid login') if status >= 400

      raise Magma::AuthError.new(500, 'Janus server error') if status >= 500

      return response
    end

    # Check that the user has a valid project listed in their permissions.
    def has_project_permission?(user_info)
      user_info[:permissions].any? do |perm|
        perm[:project_name] == @params[:project_name]
      end
    end
  end
end
