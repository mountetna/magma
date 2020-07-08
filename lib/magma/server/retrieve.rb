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
    @collapse_tables = @params[:collapse_tables] || @params[:format] == "tsv"
    @filter = @params[:filter]
    @format = @params[:format] || "json"
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

      return failure(422, errors: @errors) unless success?

      perform
    rescue ArgumentError => e
      puts e.backtrace
      return failure 422, errors: [ e.message ]
    end
  end

  private

  def validate
    return error('`model_name` is required') if @model_name.nil?
    return error('`record_names` must be Array, or `all`') unless valid_record_names?
    return error('`attribute_names` must be Array, `all`, or `identifier`') unless @attribute_names.is_a?(Array) || @attribute_names == 'all' || @attribute_names == 'identifier'
    return error('Cannot retrieve by record name for all models') if @model_name == 'all' && @record_names.is_a?(Array) && !@record_names.empty?
    return error('`attribute_name` must be `identifier` for model_name: all, record_names: all') if @model_name == 'all' && @record_names == 'all' && @attribute_names != 'identifier'
    return error('`model_name` cannot be `all` for format: tsv ') if @model_name == 'all' && @format == 'tsv'
  end

  def valid_record_names?
    @record_names && @record_names.is_a?(Array) &&
      (@record_names.all?{|name| name.is_a?(String)} ||
       @record_names.all?{|name| name.is_a?(Integer)}) ||
      @record_names == 'all'
  end

  def perform
    @payload = Magma::Payload.new

    case @format
    when 'tsv'
      tsv_payload
    else
      json_payload
    end
  end

  def json_payload
    if @model_name == 'all'
      Magma.instance.get_project(@project_name).models.each do |model_name, model|
        next if @attribute_names == 'identifier' && !model.has_identifier?
        retrieve_model(
          model, @record_names, @attribute_names,
          [], true, false
        )
      end
    else
      retrieve_model(
        Magma.instance.get_model(@project_name, @model_name),
        @record_names,
        @attribute_names,
        [ Magma::Retrieval::StringFilter.new(@filter) ],
        true,
        !@collapse_tables
      )
    end

    return success(@payload.to_hash.to_json, 'application/json')
  end

  def tsv_payload
    model = Magma.instance.get_model(@project_name, @model_name)

    retrieval = Magma::Retrieval.new(
      model,
      @record_names,
      @attribute_names,
      filters: [ Magma::Retrieval::StringFilter.new(@filter) ],
      collapse_tables: true,
      restrict: !@user.can_see_restricted?(@project_name)
    )

    tsv_stream = Enumerator.new do |stream|
      Magma::TSVWriter.new(model, retrieval, @payload).write_tsv{ |lines| stream << lines }
    end

    return [ 200, { 'Content-Type' => 'text/tsv' }, tsv_stream ]
  end

  def retrieve_model(model, record_names, attribute_names, filters, use_pages, get_tables)
    # Extract the attributes from the model.
    retrieval = Magma::Retrieval.new(
      model,
      record_names,
      attribute_names,
      filters: filters,
      collapse_tables: @collapse_tables,
      page: use_pages && @page,
      page_size: use_pages && @page_size,
      restrict: !@user.can_see_restricted?(@project_name)
    )

    @payload.add_model(model, retrieval.attribute_names)
    @payload.add_count(model, retrieval.count) if @page == 1

    return if record_names.empty?

    time = Time.now
    records = retrieval.records

    @payload.add_records( model, records )

    # add the records for any table attributes
    # This requires a secondary query.
    return unless get_tables

    retrieval.table_attributes.each do |att|
      retrieve_model(
        att.link_model,
        'all',
        'all',
        [
          Magma::Retrieval::ParentFilter.new(
            att.link_model, model,
            records.map{|r| r[model.identity]}
          )
        ],
        false,
        false
      )
    end
  end
end
