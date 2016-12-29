require_relative 'controller'

class Magma
  class Server
    class Retrieve < Magma::Server::Controller
      # Okay, now we have an actual request, let's see what it looks like.
      def response
        if success?
          success @payload.to_hash
        else
          return failure(422, errors: @errors)
        end
      end
 
      def initialize request
        super request

        @model_name =  @params["model_name"]
        @record_names = @params["record_names"]
        @attribute_names = (@params["attributes"] || []).map(&:to_sym)
        @collapse_tables =  @params["collapse_tables"]

        @errors = []
      end

      def perform
        return error('No model name given') if @model_name.nil?
        return error('No record names given') if @record_names.nil?

        @model = Magma.instance.get_model @model_name
        
        @attributes = @model.attributes.values.select do |att|
          get_attribute?(att) || show_table_attribute?(att)
        end.map(&:name)

        records = @model.eager(
          @attributes.map(&:eager).compact
        ).where(
          @model.identity => @record_names
        ).all

        @payload = Magma::Payload.new
        @payload.add_model(@model, @attributes)
        @payload.add_records( @model, records)
      end

      private

      def success?
        @errors && @errors.empty?
      end

      def error msg
        @errors.push msg
      end

      def show_table_attribute? att
        if @collapse_tables
          att.is_a?(Magma::TableAttribute) ? nil : true
        else
          nil
        end
      end

      def get_attribute? att
        if @attribute_names.empty?
          nil
        else
          @attribute_names.include? att.name
        end
      end
    end     
  end
end
