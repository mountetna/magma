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

    def valid_new_entry
      return nil unless valid?
      return nil if record_exists?
      entry
    end

    def valid_update_entry
      return nil unless valid?
      return nil unless record_exists?
      return nil unless record_changed?
      update_entry
    end

    def valid?
      @valid
    end

    private
    def record_exists?
      @klass.identity && !@klass[@klass.identity => @document[@klass.identity]].nil?
    end

    def entry
      entry = @document.clone
      # replace the entry with the appropriate values for the column
      entry.map do |att,value|
        @klass.attributes[att].entry_for value, (record||@document)
      end.reduce :merge
    end

    def update_entry
      entry[:id] = record.id
      # never overwrite created_at
      entry.delete :created_at
      entry
    end

    def record
      @record ||= @klass[@klass.identity => @document[@klass.identity]]
    end

    def record_changed?
      @document.each do |att,value|
        if att =~ /_id$/
          old_value = record.send(att.to_s.sub(/_id$/,'').to_sym)
          old_value = old_value ? old_value.id : nil
        else
          old_value = record.send att.to_sym
        end
        if value.to_s != old_value.to_s
          return true
        end
      end
      nil
    end

    def check_document_validity
      if @klass.identity && !@document[@klass.identity]
        complain "Missing identifier for #{@klass.name}"
        @valid = false
        return
      end
      @document.each do |att,value|
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
    end
    def push_record klass, document
      @records[klass] ||= []
      @records[klass] << RecordEntry.new(klass, document)
    end

    def dispatch_record_set
      @records.keys.each do |klass|
        complaints = @records[klass].map(&:complaints).flatten

        raise Magma::LoadFailed.new(complaints) unless complaints.empty?

        insert_records = @records[klass].map(&:valid_new_entry).compact

        update_records = @records[klass].map(&:valid_update_entry).compact

        # Now we have a list of valid records to insert for this class, let's create them:
        klass.multi_insert insert_records
        klass.multi_update update_records
      end
      @records = {}
    end
  end
end
