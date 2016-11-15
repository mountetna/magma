class Magma
  class JsonBody
    def initialize app
      @app = app
    end
    def call(env)
      if env['CONTENT_TYPE'] =~ %r{application/json}i
        body = env['rack.input'].read
        if body =~ %r/^\s*\{/
          env.update(
            'rack.request.json' => JSON.parse(body)
          )
        end
      end
      @app.call(env)
    end
  end
end
