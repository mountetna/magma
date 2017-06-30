class Magma
  # some vocabulary:
  # A 'model' is the class representing a database table
  # A 'record' is an instance of a database model.
  # A 'template' is a json object describing a model
  # A 'document' is a json object describing a record
  # An 'entry' is a hash suitable for database loading prepared from a document
  class LoadFailed < Exception
    attr_reader :complaints
    def initialize(complaints)
      @complaints = complaints
    end
  end

  class RecordSet < Array
    def initialize(model, validator, loader)
      @model = model
      @validator = validator
      @loader = loader
      @model_validation = @validator.model_validation(@model)
      @attribute_entries = {}
    end

    def identifier_id
      @identifier_id ||= Hash[@model.select_map([@model.identity, :id])]
    end

    def attribute_entry(att_name,value)
      attribute_entries(att_name).entry(value)
    end

    def validate(document)
      if @model.has_identifier? && !document[@model.identity]
        yield "Missing identifier for #{@model.name}"
      end
      @model_validation.validate(document) do |error|
        yield error
      end
    end

    private

    def validation
      @validation ||= @model.validation
    end

    def attribute_entries(att_name)
      @attribute_entries[att_name] ||= @model.attributes[att_name].entry.new(
        @model, @model.attributes[att_name], @loader
      )
    end
  end

  class RecordEntry
    def initialize(model, document, set, loader)
      @document = document
      @model = model
      @set = set
      @loader = loader
      @complaints = []
      @valid = true

      check_document_validity
    end

    attr_reader :complaints
    attr_accessor :real_id

    def valid_new_entry?
      valid? && !record_exists?
    end

    def valid_update_entry?
      valid? && record_exists?
    end

    def valid_temp_update?
      valid? && needs_temp?
    end

    def valid?
      @valid
    end

    def needs_temp?
      @needs_temp
    end

    def insert_entry
      Hash[
        @document.map do |att_name,value|
          # filter out temp ids
          if att_name == :temp_id
            value.record_entry = self
            next
          end
          if value.is_a? Magma::TempId
            @needs_temp = true
            next
          end
          @loader.attribute_entry(@model, att_name, value)
        end.compact
      ]
    end

    def update_entry
      entry = insert_entry
      entry[:id] = @loader.identifier_id(@model, @document[@model.identity])
      # never overwrite created_at
      entry.delete :created_at
      entry
    end

    def temp_entry
      entry = @document.clone
      # replace the entry with the appropriate values for the column
      Hash[
        entry.map do |att_name,value|
          if att_name == :temp_id
            [ :real_id, value.real_id ]
          elsif value.is_a? Magma::TempId
            @loader.attribute_entry(@model, att_name, value)
          else
            nil
          end
        end.compact
      ]
    end

    private
    def record_exists?
      @model.has_identifier? && @loader.identifier_exists?(@model,@document[@model.identity])
    end

    def check_document_validity
      @set.validate(@document) do |complaint|
        complain complaint
        @valid = false
      end
    end

    def complain plaint
      @complaints << plaint
    end
  end

  class BaseAttributeEntry
    def initialize(model, attribute, loader)
      @model = model
      @attribute = attribute
      @loader = loader
    end

    def entry value
      nil
    end
  end

  class Loader
    # A generic loader class
    class << self
      def description desc=nil
        @description ||= desc
      end

      def loader_name
        name.snake_case.sub(/_loader$/,'')
      end
    end

    def initialize
      @records = {}
      @temp_id_counter = 0
      @validator = Magma::Validator.new
    end

    def push_record(model, document)
      records(model) << RecordEntry.new(model, document, records(model), self)
    end

    def attribute_entry(model, att_name, value)
      records(model).attribute_entry(att_name,value)
    end

    def identifier_id(model, identifier)
      records(model).identifier_id[identifier]
    end
    alias_method :identifier_exists?, :identifier_id

    def records(model)
      return @records[model] if @records[model]
      
      @records[model] = RecordSet.new(model, @validator, self)
      ensure_link_models(model)

      @records[model]
    end

    def dispatch_record_set
      find_complaints

      initial_insert

      update_temp_ids

      reset
    end

    def reset
      @records = {}
      @validator = Magma::Validator.new
      GC.start
    end

    # this lets you give an arbitrary object (e.g. a model used in the loader) a temporary id
    # so you can make database associations
    def temp_id obj
      return nil if obj.nil?
      temp_ids[obj] ||= TempId.new(new_temp_id, obj)
    end

    private

    def find_complaints
      complaints = []
      @records.each do |model,record_set|
        next if record_set.empty?
        complaints.concat record_set.map(&:complaints)
      end
      complaints.flatten!
      raise Magma::LoadFailed.new(complaints) unless complaints.empty?
    end

    def initial_insert
      @inserted = []
      puts "Attempting initial insert"
      @records.each do |model,record_set|
        next if record_set.empty?

        insert_records = record_set.select(&:valid_new_entry?)
        update_records = record_set.select(&:valid_update_entry?)

        puts "Found #{insert_records.count} records to insert and #{update_records.count} records to update for #{model}"


        insert_ids = model.multi_insert(
          insert_records.map(&:insert_entry),
          return: :primary_key
        )

        if insert_ids
          puts "Updating temp records with real ids for #{model}"
          insert_records.zip(insert_ids).each do |record, real_id|
            record.real_id = real_id
          end
        end

        model.multi_update(
          records: update_records.map(&:update_entry)
        )
      end
    end

    def update_temp_ids
      @records.each do |model, record_set|
        next if record_set.empty?
        temp_records = record_set.select(&:valid_temp_update?)
        puts "Found #{temp_records.count} records to repair temp_ids for #{model}"
        model.multi_update records: temp_records.map(&:temp_entry), src_id: :real_id, dest_id: :id
      end
    end

    def temp_ids
      @temp_ids ||= {}
    end

    def new_temp_id
      @temp_id_counter += 1
    end

    def ensure_link_models model
      model.attributes.each do |att_name, att|
        records(att.link_model) if att.is_a?(Magma::Link)
      end
    end
  end

  class TempId
    # This marks the column as a temporary id. It needs to be replaced with a real foreign key id for the corresponding
    # object once it is complete.
    attr_reader :obj, :id
    attr_accessor :record_entry
    def initialize(id, obj)
      @obj = obj
      @id = id
    end

    def real_id
      record_entry.real_id
    end
  end
end

require_relative './loaders/tsv'
