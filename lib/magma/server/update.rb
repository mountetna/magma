require_relative 'controller'

class Magma
  class Server
    class Update < Magma::Server::Controller
      def response
        payload = Magma::Payload.new
        revisions = @params["revisions"].map do |model_name, model_revisions|
          model_revisions.map do |record_name, revision_data|
            Magma::Revision.new(revision_data, model_name, record_name)
          end
        end.flatten

        revisions.each do |revision|
          error(revision.errors) if !revision.valid?
        end

        if success?
          revisions.each do |revision|
            begin
              revision.post!
            rescue Magma::LoadFailed => m
              log m.complaints
              @errors.concat m.complaints
              next
            end
            payload.add_revision revision
          end
        end

        if success?
          success 'application/json', payload.to_hash.to_json
        else
          failure(422, errors: @errors)
        end
      end
    end
  end
end
