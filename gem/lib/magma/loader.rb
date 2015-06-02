class Magma
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

    def valid_new_document 
      return nil unless valid?
      return nil if item_exists?
      @document
    end

    def valid?
      @valid
    end

    private
    def item_exists?
      @klass.identity && @klass[@klass.identity => @document[@klass.identity]]
    end

    def check_document_validity
      if @klass.identity && !@document[@klass.identity]
        complain "Missing identifier for #{@klass.name}"
        @valid = false
        return
      end
      @document.each do |att,value|
        att = att.to_s.sub(/_id$/,'').to_sym
        if !@klass.attributes[att]
          complain "#{@klass.name} has no attribute '#{att}'"
          @valid = false
          next
        end
        @klass.attributes[att].validate(value) do |complaint|
          complain complaint
          @valid = false
        end
      end
    end

    def complain laint
      @complaints << laint
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

        insert_records = @records[klass].map(&:valid_new_document).compact

        # Now we have a list of valid records to insert for this class, let's create them:
        
        klass.multi_insert insert_records
      end
      @records = {}
    end
  end
end
