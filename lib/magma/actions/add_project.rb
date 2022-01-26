class Magma

  class AddProjectAction < ComposedAction
    def perform
      # Unfortunately we cannot just run a create and catch the error due to the way ruby sequel poorly handles graceful
      # recovery of error inside transaction, which this is run inside of implicitly from parent caller.
      Magma.instance.db.run <<-SQL
DO $$
BEGIN
    IF NOT EXISTS(
        SELECT schema_name
          FROM information_schema.schemata
          WHERE schema_name = '#{@project_name}'
      )
    THEN
      EXECUTE 'CREATE SCHEMA #{@project_name}';
    END IF;
END
$$;
      SQL
      setup_metis unless @action_params[:no_metis_bucket]
      super
    end

    def validations
      [
          :validate_project_name
      ]
    end

    def validate_project_name
      return if @project_name =~ /\A[a-z][a-z0-9]*(_[a-z][a-z0-9]*)*\Z/ && !@project_name.start_with?('pg_')
      @errors << Magma::ActionError.new(
          message: "project_name must be snake_case with no spaces",
          source: @action_params.slice(:project_name)
      )
    end

    private

    def setup_metis
      # Create a Metis bucket, owned by Magma,
      #   for linking files into.
      host = Magma.instance.config(:storage).fetch(:host)

      client = Etna::Client.new("https://#{host}", @action_params[:user].token)

      bucket_create_route = client.routes.find { |r| r[:name] == 'bucket_create' }

      begin
        @errors << Magma::ActionError.new(
          message: "No bucket_create route on the Metis storage host -- will not be able to link files for this",
          source: 'setup_metis'
        )
        return nil
      end unless bucket_create_route

      path = client.route_path(
        bucket_create_route,
        project_name: @project_name,
        bucket_name: 'magma'
      )

      params = {
        owner: 'magma',
        description: 'For magma use only',
        access: 'administrator'
      }

      # Now populate the standard headers
      hmac_params = {
        method: 'POST',
        host: host,
        path: path,

        expiration: (DateTime.now + 10).iso8601,
        id: 'magma',
        nonce: SecureRandom.hex,
        headers: params,
      }

      hmac = Etna::Hmac.new(Magma.instance, hmac_params)

      client.send(
        'body_request',
        Net::HTTP::Post,
        hmac.url_params[:path] + '?' + hmac.url_params[:query],
        params)

      return nil
    rescue Etna::Error => e
      Magma.instance.logger.log_error(e)
    end

    def project
      Magma.instance.get_or_load_project(@project_name)
    end

    def make_actions
      if project.models.include? :project
        []
      else
        [AddModelAction.new(@project_name, model_name: 'project', identifier: 'name')]
      end
    end
  end
end
