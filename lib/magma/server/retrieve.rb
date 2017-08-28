require_relative 'controller'
require 'pry'

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
        # Check the input.
        check_params
        return failure(422, errors: @errors) unless success?

        # Run the db query.
        perform

        # Format the output.
        case @format
        when 'tsv'
          return success('text/tsv', @payload.to_tsv)
        else
          return success('application/json', @payload.to_hash.to_json)
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

      def perform
        # Set up the return object.
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
        @attributes = model.attributes.values.select do |att|
          get_attribute?(att, model)
        end

        # Extract the attributes that need to be 'eager'-ly loaded and then
        # eagerly load the attributes referenced in a separate db table.
        dataset = model.eager(@attributes.map(&:eager).compact)

        # If there are multiple records being requested then generate a SQL
        # sql query that matches.
        if @record_names.is_a?(Array)
          dataset = dataset.where({model.identity=> @record_names})
        end

        # TODO: Replace this with a pure-SQL version that returns a hash for 
        # this record.
        #
        # Run the SQL query to pull the records.
        records = dataset.all

        @payload.add_model(model, @attributes.map(&:name))
        @payload.add_records(model, records)
        pull_table_data(records)

        puts("Retrieving #{model.name} took #{Time.now - time} seconds")
      end

      private

      # Add the records for any table attributes.
      def pull_table_data(records)
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
