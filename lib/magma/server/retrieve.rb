require_relative 'controller'

# In general, you Retrieve with a request like this:
# {
#   model_name: "model",
#   record_names: [ "record1", "record2" ],
#   attribute_names: [ "att_a", "att_b" ]
# }
#
# Some special cases:
#
# This will pull all attributes for the requested records
# {
#   model_name: "model",
#   record_names: [ "record1", "record2" ],
#   attribute_names: "all"
# }
#
# This will pull all records for the given model
# {
#   model_name: "model",
#   record_names: "all",
#   attribute_names: ...
# }
#
# This will pull all identifiers for all models and records
# {
#   model_name: "all",
#   record_names: "all",
#   attribute_names: "identifier"
# }

class Magma
  class Server
    class Retrieve < Magma::Server::Controller
      def response
        perform

        if success?
          case @format
          when "tsv"
            success 'text/tsv', @payload.to_tsv
          else
            success 'application/json', @payload.to_hash.to_json
          end
        else
          failure(422, errors: @errors)
        end
      end

      def initialize request
        super request

        @model_name =  @params[:model_name]
        @record_names = @params[:record_names]
        @attribute_names = @params[:attribute_names].is_a?(Array) ? @params[:attribute_names].map(&:to_sym) : @params[:attribute_names]
        @collapse_tables =  @params[:collapse_tables] || @params[:format] == "tsv"
        @format = @params[:format] || "json"
      end

      def perform
        return error('No model name given') if @model_name.nil?
        return error('No record names given') if @record_names.nil?
        return error('Improperly formed record names') unless valid_record_names?
        return error("Improperly formed attribute names") unless @attribute_names.is_a?(Array) || @attribute_names == "all" || @attribute_names == "identifier"
        return error('Cannot retrieve several models in tsv format') if @model_name == "all" && @format == "tsv"

        @payload = Magma::Payload.new

        if @model_name == "all"
          Magma.instance.magma_models.each do |model|
            next if @attribute_names == "identifier" && !model.has_identifier?
            retrieve_model(model)
          end
        else
          retrieve_model(Magma.instance.get_model @model_name)
        end
      end

      def retrieve_model model
        time = Time.now
        @attributes = model.attributes.values.select do |att|
          get_attribute?(att,model)
        end

        records = model.eager(@attributes.map(&:eager).compact)

        if @record_names.is_a?(Array)
          records = records.where(
            model.identity => @record_names
          )
        end

        # later: replace this with a pure-SQL version
        # that returns a hash for this record
        records = records.all

        @payload.add_model(model, @attributes.map(&:name))
        @payload.add_records( model, records)

        # add the records for any table attributes
        if !@collapse_tables
          @attributes.each do |att|
            next unless att.is_a?(Magma::TableAttribute)

            link_model = att.link_model
            link_model_attribute_names = link_model.attributes.select do |att_name, att|
              att.shown? && !att.is_a?(Magma::TableAttribute)
            end.map(&:first)

            @payload.add_model(link_model, link_model_attribute_names)
            records.each do |record|
              @payload.add_records(link_model, record.send(att.name))
            end
          end
        end
      end

      private

      def valid_record_names?
        @record_names.is_a?(Array) && 
          (@record_names.all?{|name| name.is_a?(String)} ||
           @record_names.all?{|name| name.is_a?(Fixnum)}) || 
          @record_names == "all"
      end

      def get_attribute? att, model
        return false if @collapse_tables && att.is_a?(Magma::TableAttribute)
        @attribute_names == "all" ||
          (@attribute_names == "identifier" && model.identity == att.name) ||
          (@attribute_names.is_a?(Array) && @attribute_names.include?(att.name))
      end
    end
  end
end
