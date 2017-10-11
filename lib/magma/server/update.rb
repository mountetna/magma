require_relative 'controller'

class Magma
  class Server
    class Update < Magma::Server::Controller
      def response
        payload = Magma::Payload.new
        validator = Magma::Validator.new

        revisions = @params[:revisions].map do |model_name, model_revisions|
          model = Magma.instance.get_model(@project_name, model_name)

          model_revisions.map do |record_name, revision_data|
            Magma::Revision.new(model, record_name.to_s, revision_data, validator)
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
          end
        end

        if success?
          revisions.group_by(&:model).each do |model,model_revisions|
            attribute_names = model_revisions.first.attribute_names

            payload.add_model(model, attribute_names)

            records = Magma::Retrieval.new(
              model,
              model_revisions.map(&:record_name),
              attribute_names.map { |att_name| model.attributes[att_name] }
            ).records

            payload.add_records(model, records)
          end
          success 'application/json', payload.to_hash.to_json
        else
          failure(422, errors: @errors)
        end
      end
    end
  end
end
