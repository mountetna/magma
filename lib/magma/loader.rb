class Magma
  # some vocabulary:
  # A 'model' is the class representing a database table
  # A 'record' is an instance of a database model.
  # A 'template' is a json object describing a model
  # A 'document' is a json object describing a record
  # An 'entry' is a hash suitable for database loading prepared from a document
  class LoadFailed < Exception
    attr_reader :complaints
    def initialize complaints
      @complaints = complaints
    end
  end

  class RecordEntry
    def initialize model, document
      @document = document
      @model = model
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

    def entry
      entry = @document.clone
      # replace the entry with the appropriate values for the column
      Hash[
        entry.map do |att,value|
          # filter out temp ids
          if att == :temp_id
            value.record_entry = self
            next
          end
          if value.is_a? Magma::TempId
            @needs_temp = true
            next
          end
          @model.attributes[att].entry_for value
        end.compact
      ]
    end

    def update_entry
      entry[:id] = record.id
      # never overwrite created_at
      entry.delete :created_at
      entry
    end

    def temp_entry
      entry = @document.clone
      # replace the entry with the appropriate values for the column
      Hash[
        entry.map do |att,value|
          if att == :temp_id
            [ :real_id, value.real_id ]
          elsif value.is_a? Magma::TempId
            @model.attributes[att].entry_for value
          else
            nil
          end
        end.compact
      ]
    end

    private
    def record_exists?
      @model.has_identifier? && @model.identifier_id[@document[@model.identity]]
    end

    def check_document_validity
      if @model.has_identifier? && !@document[@model.identity]
        complain "Missing identifier for #{@model.name}"
        @valid = false
        return
      end
      @document.each do |att,value|
        if att == :temp_id
          unless value.is_a? Magma::TempId
            complain "temp_id should be of class Magma::TempId"
            @valid = false
          end
          next
        end
        if !@model.attributes[att]
          complain "#{@model.name} has no attribute '#{att}'"
          @valid = false
          next
        end
        @model.attributes[att].validate(value) do |complaint|
          complain complaint
          @valid = false
        end
      end
    end

    def complain plaint
      @complaints << plaint
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
    end

    def push_record model, document
      @records[model] ||= []
      @records[model] << RecordEntry.new(model, document)
    end

    def dispatch_record_set
      find_complaints

      initial_insert

      update_temp_ids

      @records = {}
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
      @records.keys.each do |model|
        complaints.concat @records[model].map(&:complaints)
      end
      complaints.flatten!
      raise Magma::LoadFailed.new(complaints) unless complaints.empty?
    end

    def initial_insert
      @inserted = []
      puts "Attempting initial insert"
      @records.keys.each do |model|

        insert_records = @records[model].select(&:valid_new_entry?)
        update_records = @records[model].select(&:valid_update_entry?)

        puts "Found #{insert_records.count} records to insert and #{update_records.count} records to update for #{model}"

        entries = insert_records.map(&:entry)

        puts "#{DateTime.now} Generated entries..."

        insert_ids = model.multi_insert entries, return: :primary_key

        if insert_ids
          puts "Updating temp records with real ids for #{model}"
          insert_records.zip(insert_ids).each do |record, real_id|
            record.real_id = real_id
          end
        end

        model.multi_update records: update_records.map(&:update_entry)
      end
    end

    def update_temp_ids
      @records.keys.each do |model|
        temp_records = @records[model].select(&:valid_temp_update?)
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
