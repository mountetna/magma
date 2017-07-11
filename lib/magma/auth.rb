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
  end

  class Auth
    def initialize(app, config)
      @app = app
      @config = config
    end

    def call(env)
      @request = Rack::Request.new(env)
      @params = @request.env['rack.request.params']

      begin
        # The checks required before we call Janus.
        pre_janus_check

        # Make the request to Janus.
        data = {:token=> @params[:token], :app_key=> @config[:app_key]}
        response = make_request(@config[:janus_addr]+'/check', data).body
        response = JSON.parse(response)

        # The checks require after we call Janus.
        post_janus_check(response)
      rescue AuthError=> err
        return send_err(err.status, err.body)
      end

      # Set the user's permissions on the 'env' object, and carry on!
      env.merge!({'user_info'=> response['user_info']})

      # Carry on!
      @app.call(env)
    end

    def pre_janus_check
      # Check for the params.
      if @params == nil
        raise_err(400, {errors: ['No parameters.']})
      end

      # Check for the token.
      if @params[:token].nil?
        raise_err(400, {errors: ['Invalid login.']})
      end

      # Check for the project name.
      if @params[:project_name].nil?
        raise_err(400, {errors: ['No project.']})
      end

      # Check for the app key.
      if @config[:app_key].nil?
        raise_err(400, {errors: ['No app key.']})
      end
    end

    def post_janus_check(response)
      # Check the response from Janus.
      if !response.key?('success')
        raise_err(500, {errors: ['The Janus response is malformed.']}) 
      end

      if !response['success']
        raise_err(400, {errors: ['Invalid login.']}) 
      end

      # Check that the user has some permission for the project requested.
      if !project_valid?(response)
        raise_err(400, {errors: ['Invalid project.']})
      end
    end

    # Make a request to Janus for the user permissions.
    def make_request(url, data)
      begin
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
        if status >= 400
          return send_err(status, {errors: ['A Janus server error occurred.']})
        end

        return response
      rescue
        return send_err(500, {errors: ['A Janus connection error occurred.']})
      end
    end

    # Check that the user has a valid project listed in their permissions.
    def project_valid?(response)
      valid = false
      response['user_info']['permissions'].each do |perm|
        if perm['project_name'] == @params[:project_name]
          valid = true
          break
        end
      end
      return valid
    end

    def raise_err(status, body)
      raise Magma::AuthError.new(status, body)
    end

    def send_err(status, body)
      return Rack::Response.new(body.to_json, status)
    end
  end
end
