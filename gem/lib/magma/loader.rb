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
    def initialize klass, document
      @document = document
      @klass = klass
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
      valid? && record_exists? && record_changed?
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
        @klass.attributes[att].entry_for value, (record||@document)
      end.compact.reduce :merge
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
      entry.map do |att,value|
        if att == :temp_id
          { real_id: value.real_id }
        elsif value.is_a? Magma::TempId
          @klass.attributes[att].entry_for value, (record||@document)
        else
          nil
        end
      end.compact.reduce :merge
    end

    private
    def record_exists?
      @klass.identity && !@klass[@klass.identity => @document[@klass.identity]].nil?
    end

    def record
      @record ||= @klass[@klass.identity => @document[@klass.identity]]
    end

    def record_changed?
      @document.each do |att,value|
        next if att == :temp_id
        old_value = record.send att.to_sym
        return true if value.to_s != old_value.to_s
      end
      nil
    end

    def check_document_validity
      if @klass.identity && @klass.identity != @klass.primary_key && !@document[@klass.identity]
        complain "Missing identifier for #{@klass.name}"
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
        if !@klass.attributes[att]
          complain "#{@klass.name} has no attribute '#{att}'"
          @valid = false
          next
        end
        @klass.attributes[att].validate(value, @document) do |complaint|
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
    def initialize
      @records = {}
      @temp_id_counter = 0
    end

    def push_record klass, document
      @records[klass] ||= []
      @records[klass] << RecordEntry.new(klass, document)
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
      temp_ids[obj] ||= TempId.new(self.temp_id_counter += 1, obj)
    end

    private
    def find_complaints
      complaints = []
      @records.keys.each do |klass|
        complaints.concat @records[klass].map(&:complaints)
      end
      complaints.flatten!
      raise Magma::LoadFailed.new(complaints) unless complaints.empty?
    end

    def initial_insert
      @inserted = []
      puts "Attempting initial insert"
      @records.keys.each do |klass|

        insert_records = @records[klass].select(&:valid_new_entry?)
        update_records = @records[klass].select(&:valid_update_entry?)

        puts "Found #{insert_records.count} records to insert and #{update_records.count} records to update for #{klass}"

        insert_ids = klass.multi_insert insert_records.map(&:entry), return: :primary_key

        if insert_ids
          puts "Updating temp records with real ids for #{klass}"
          insert_records.zip(insert_ids).each do |record, real_id|
            record.real_id = real_id
          end
        end

        klass.multi_update records: update_records.map(&:update_entry)
      end
    end

    def update_temp_ids
      @records.keys.each do |klass|
        temp_records = @records[klass].select(&:valid_temp_update?)
        puts "Found #{temp_records.count} records to repair temp_ids for #{klass}"
        puts temp_records.map(&:temp_entry)
        klass.multi_update records: temp_records.map(&:temp_entry), src_id: :real_id, dest_id: :id
      end
    end

    def temp_ids
      @temp_ids ||= {}
    end
    attr_accessor :temp_id_counter
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
