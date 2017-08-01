require_relative 'controller'
require_relative '../retrieval'
require 'ostruct'

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
        @model_name = @params[:model_name]
        @record_names = @params[:record_names]
        @collapse_tables = @params[:collapse_tables] || @params[:format] == "tsv"
        @filter = @params[:filter]
        @format = @params[:format] || "json"

        @attribute_names = @params[:attribute_names]
        if @params[:attribute_names].is_a?(Array)
          @attribute_names = @params[:attribute_names].map(&:to_sym)
        end
      end

      def response
        begin
          validate

          if success?
            case @format
            when "tsv"
              return [ 200, { 'Content-Type' => 'text/tsv' }, tsv_payload ]
            else
              perform
              return success('application/json', @payload.to_hash.to_json)
            end
          else
            return failure(422, errors: @errors)
          end
        rescue ArgumentError => e
          puts e.backtrace
          return failure 422, errors: [ e.message ]
        end
      end

      def initialize request
        super request

        @model_name =  @params[:model_name]
        @record_names = @params[:record_names]
        @attribute_names = @params[:attribute_names].is_a?(Array) ? @params[:attribute_names].map(&:to_sym) : @params[:attribute_names]
        @collapse_tables =  @params[:collapse_tables] || @params[:format] == "tsv"
        @filter = @params[:filter]
        @page = @params[:page]
        @page_size = @params[:page_size]
        @format = @params[:format] || "json"
      end

      private

      def validate
        return error('No model name given') if @model_name.nil?
        return error('No record names given') if @record_names.nil?
        return error('Improperly formed record names') unless valid_record_names?
        return error("Improperly formed attribute names") unless @attribute_names.is_a?(Array) || @attribute_names == "all" || @attribute_names == "identifier"
        return error('Cannot retrieve by record name for all models') if @model_name == "all" && @record_names.is_a?(Array) && !@record_names.empty?
        return error('Cannot retrieve several models in tsv format') if @model_name == "all" && @format == "tsv"
      end

      def valid_record_names?
        @record_names.is_a?(Array) && 
          (@record_names.all?{|name| name.is_a?(String)} ||
           @record_names.all?{|name| name.is_a?(Fixnum)}) || 
          @record_names == "all"
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


      def retrieve_model model
        # Extract the attributes from the model.
        attributes = selected_attributes(model)
        return if attributes.empty?

        retrieval = Magma::Retrieval.new(
          model,
          @record_names,
          attributes, 
          @filter,
          @page,
          @page_size
        )
        @payload.add_model(model, retrieval.attribute_names)
        
        @payload.add_count(model, retrieval.count) if @page == 1

        if !@record_names.empty?
          time = Time.now
          records = retrieval.records
          puts "Retrieving #{model.model_name} took #{Time.now - time} seconds"
          @payload.add_records( model, records )
        end

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

      def tsv_payload
        @payload = Magma::Payload.new

        model = Magma.instance.get_model(@model_name)
        attributes = selected_attributes(model)
        return if attributes.empty?

        retrieval = Magma::Retrieval.new(
          model,
          @record_names,
          attributes, 
          @filter
        )
        @payload.add_model(model, retrieval.attribute_names)
        return Enumerator.new do |stream|
          stream << @payload.tsv_header
          retrieval.each_page do |records|
            @payload.add_records(model, records)
            stream << @payload.to_tsv
            @payload.reset(model)
          end
        end
      end

      def selected_attributes model
        attributes = model.attributes.values.select do |att|
          get_attribute?(att,model)
        end
        if !model.has_identifier?
          attributes.push(OpenStruct.new(name: :id))
        end
        attributes
      end

      def get_attribute?(att, model)
        return false if @collapse_tables && att.is_a?(Magma::TableAttribute)
        @attribute_names == "all" ||
          (model.identity == att.name) ||
          (@attribute_names.is_a?(Array) && @attribute_names.include?(att.name))
      end
    end
  end
end
