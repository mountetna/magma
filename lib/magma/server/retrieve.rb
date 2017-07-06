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
      def initialize(request)
        super(request)
        @model_name =  @params[:model_name]
        @record_names = @params[:record_names]
        @collapse_tables =@params[:collapse_tables] || @params[:format] == 'tsv'
        @format = @params[:format] || 'json'

        @attribute_names = @params[:attribute_names]
        if @params[:attribute_names].is_a?(Array)
          @attribute_names = @params[:attribute_names].map(&:to_sym)
        end
      end

      def response
        validate

        if success?
          perform
          case @format
          when "tsv"
            success 'text/tsv', @payload.to_tsv
          else
            success 'application/json', @payload.to_hash.to_json
          end
        else
          return failure(422, errors: @errors) unless success?
        end
      end

      def check_params
        error('No model name given') if @model_name.nil?
        error('No record names given') if @record_names.nil?
        error('Improperly formed record names') unless valid_record_names?

        unless(@attribute_names.is_a?(Array) || @attribute_names == 'all' ||
          @attribute_names == 'identifier')
          error('Improperly formed attribute names') 
        end

        if @model_name == 'all' && @format == 'tsv'
          error('Cannot retrieve several models in tsv format') 
        end
      end

      private

      def validate
        return error('No model name given') if @model_name.nil?
        return error('No record names given') if @record_names.nil?
        return error('Improperly formed record names') unless valid_record_names?
        return error("Improperly formed attribute names") unless @attribute_names.is_a?(Array) || @attribute_names == "all" || @attribute_names == "identifier"
        return error('Cannot retrieve by record name for all models') if @model_name == "all" && @record_names.is_a?(Array)
        return error('Cannot retrieve several models in tsv format') if @model_name == "all" && @format == "tsv"
      end

      def perform
        @payload = Magma::Payload.new

        # Pull the data.
        if @model_name == 'all'
          Magma.instance.magma_models.each do |model|
            next if @attribute_names == 'identifier' && !model.has_identifier?
            retrieve_model(model)
          end
        else

          # The '@project_name' is set in Magma::Server::Controller and should
          # have been passed in via the client as a param.
          retrieve_model(Magma.instance.get_model(@project_name, @model_name))
        end
      end

      def retrieve_model(model)
        time = Time.now
        # Extract the attributes from the model.
        attributes = model.attributes.values.select do |att|
          get_attribute?(att,model)
        end
        attribute_names = attributes.map(&:name)

        @payload.add_model(model, attribute_names)

        return if attributes.empty?

        query = [ model.model_name.to_s ]
        if @record_names.is_a?(Array)
          query.push [ '::identifier', '::in', @record_names ]
        end
        query.push('::all')
        query.push(
          attributes.map do |att|
            case att
            when Magma::CollectionAttribute, Magma::TableAttribute
              [ att.name.to_s, '::all', '::identifier' ]
            when Magma::ForeignKeyAttribute, Magma::ChildAttribute
              [ att.name.to_s, '::identifier' ]
            else
              [ att.name.to_s ]
            end
          end
        )

        # These records are not Sequel instances as the payload
        # expects - the payload to_hash method will fall apart here.
        # Our options are:
        # 1) compose the record here as a hash and merely make the payload a
        # thin shell
        # 2) Wrap the record in a class that quacks like a Sequel instance
        #
        # 2 is probably expensive.
        # 1 requires composition here, which is probably mostly fine except for
        # a few attribute classes like tables and collections
        records = Magma::Question.new(query).answer.map do |name, row|
          Hash[ attribute_names.zip(row) ].update( model.identity => name )
        end

        puts "Retrieving #{model.model_name} took #{Time.now - time} seconds"

        @payload.add_records( model, records )

        # add the records for any table attributes
        # This requires a secondary query.
        if !@collapse_tables
          attributes.each do |att|
            next unless att.is_a?(Magma::TableAttribute)

            retrieve_table_attribute(model, att)
          end
        end
      end

      def retrieve_table_attribute(model, attribute)
      end

      def valid_record_names?
        @record_names.is_a?(Array) && 
          (@record_names.all?{|name| name.is_a?(String)} ||
           @record_names.all?{|name| name.is_a?(Fixnum)}) || 
          @record_names == "all"
      end

      def get_attribute?(att, model)
        return false if @collapse_tables && att.is_a?(Magma::TableAttribute)
        @attribute_names == "all" ||
          (@attribute_names == "identifier" && model.identity == att.name) ||
          (@attribute_names.is_a?(Array) && @attribute_names.include?(att.name))
      end
    end
  end
end
