class Magma
  class ParseBody
    def initialize app
      @app = app
    end
    def call(env)
      case env['CONTENT_TYPE']
      when %r{application/json}i
        body = env['rack.input'].read
        if body =~ %r/^\s*\{/
          env.update(
            'rack.request.params' => JSON.parse(body)
          )
        end
      when %r{multipart/form-data}i
        env.update(
          'rack.request.params' => Rack::Multipart.parse_multipart(env)
        )
      end
      @app.call(env)
    end
  end
end
