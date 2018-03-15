require_relative 'controller'
require_relative '../retrieval'
require_relative '../tsv_writer'
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

class RetrieveController < Magma::Controller
  def initialize(request, action)
    super
    @model_name = @params[:model_name]
    @record_names = @params[:record_names]
    @collapse_tables = @params[:collapse_tables] || @params[:format] == 'tsv'
    @filter = @params[:filter]
    @format = @params[:format] || 'json'
    @page = @params[:page]
    @page_size = @params[:page_size]

    @attribute_names = @params[:attribute_names]

    if @params[:attribute_names].is_a?(Array)
      @attribute_names = @params[:attribute_names].map(&:to_sym)
    end
  end

  def action
    begin
      validate

      if success?
        case @format
        when 'tsv'
          return [200, {'Content-Type'=> 'text/tsv'}, tsv_payload]
        else
          perform
          return success(@payload.to_hash.to_json, 'application/json')
        end
      else
        return failure(422, errors: @errors)
      end
    rescue ArgumentError => e
      puts e.backtrace
      return failure 422, errors: [ e.message ]
    end
  end

  private

  def validate
    return error('No model name given.') if @model_name.nil?
    return error('No record names given.') if @record_names.nil?
    return error('Improperly formed record names.') unless valid_record_names?

    unless(
      @attribute_names.is_a?(Array) ||
      @attribute_names == 'all' ||
      @attribute_names == 'identifier'
    )
      return error('Improperly formed attribute names.')
    end

    if(
      @model_name == 'all' &&
      @record_names.is_a?(Array) &&
      !@record_names.empty?
    )
      return error('Cannot retrieve by record name for all models.')
    end

    if(
      @model_name == 'all' &&
      @record_names == 'all' &&
      @attribute_names != 'identifier'
    )
      return error('Can only retrieve identifiers for all records for all models')
    end

    if @model_name == 'all' && @format == 'tsv'
      return error('Cannot retrieve several models in tsv format') 
    end
  end

  def valid_record_names?
    (
      @record_names.is_a?(Array) &&
      (
        @record_names.all?{|name| name.is_a?(String)} ||
        @record_names.all?{|name| name.is_a?(Fixnum)}
      ) ||
      @record_names == 'all'
    )
  end

  def perform
    @payload = Magma::Payload.new

    # Pull the data.
    if @model_name == 'all'
      Magma.instance.get_project(@project_name).models.each do |model_name, model|
        next if @attribute_names == 'identifier' && !model.has_identifier?
        retrieve_model(model)
      end
    else
      # The '@project_name' is set in Magma::Controller and should have been
      # passed in via the client as a param.
      retrieve_model(Magma.instance.get_model(@project_name, @model_name))
    end
  end

  def retrieve_model(model)
    # Extract the attributes from the model.
    attributes = selected_attributes(model)
    return if attributes.empty?

    retrieval = Magma::Retrieval.new(
      model,
      @record_names,
      attributes, 
      Magma::Retrieval::StringFilter.new(@filter),
      @page,
      @page_size
    )
    @payload.add_model(model, retrieval.attribute_names)
    
    @payload.add_count(model, retrieval.count) if @page == 1

    if !@record_names.empty?
      time = Time.now
      records = retrieval.records
      puts "Retrieving #{model.model_name} took #{Time.now - time} seconds"
      @payload.add_records(model, records)

      # Add the records for any table attributes. This requires a secondary
      # query.
      if !@collapse_tables
        attributes.each do |att|
          next unless att.is_a?(Magma::TableAttribute)
          retrieve_table_attribute(model, records, att)
        end
      end
    end
  end

  def retrieve_table_attribute(model, records, attribute)
    link_model = attribute.link_model

    link_attributes = link_model.attributes.reject do |att_name, att|
      att.is_a?(Magma::TableAttribute)
    end.values
    if !link_model.has_identifier?
      link_attributes.push(OpenStruct.new(name: :id))
    end

    record_names = records.map do |record|
      record[model.identity]
    end

    retrieval = Magma::Retrieval.new(
      link_model,
      'all',
      link_attributes,
      Magma::Retrieval::ParentFilter.new(
        link_model, model, record_names
      ),

      # Some day this should be table pages.
      nil,
      nil
    )
    @payload.add_model( link_model, retrieval.attribute_names )
    @payload.add_records( link_model, retrieval.records )
  end

  def tsv_payload
    @payload = Magma::Payload.new

    model = Magma.instance.get_model(@project_name, @model_name)
    attributes = selected_attributes(model)
    return if attributes.empty?


    retrieval = Magma::Retrieval.new(
      model,
      @record_names,
      attributes,
      Magma::Retrieval::StringFilter.new(@filter)
    )

    return Enumerator.new do |stream|
      Magma::TSVWriter.new(
        model,
        retrieval,
        @payload
      ).write_tsv{ |lines| stream << lines }
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
    (
      (@attribute_names == 'all') ||
      (model.identity == att.name) ||
      (@attribute_names.is_a?(Array) && @attribute_names.include?(att.name))
    )
  end
end
