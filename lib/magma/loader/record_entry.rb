class Magma
  class RecordEntry
    attr_accessor :real_id

    def initialize(model, record_name, loader)
      @model = model
      @record_name = @model.has_identifier? ? record_name : record_name.to_i
      @loader = loader
      @record = {}
    end

    def <<(revision)
      @record.update(
        revision.map do |att_name, value|
          next unless @model.has_attribute?(att_name)
          @model.attributes[att_name].revision_to_loader( @record_name, value )
        end.compact.to_h
      )
    end

    def [](att_name)
      @record[att_name]
    end

    def has_key?(att_name)
      @record.has_key?(att_name)
    end

    def complaints
      return @complaints if @complaints
      check_document_validity

      return @complaints
    end

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
      complaints.empty?
    end

    def needs_temp?
      @needs_temp
    end

    def payload_entry
      { @model.identity.name => @record_name }.update(
        @record.map do |att_name,value|
          # filter out temp ids
          next if att_name == :temp_id || att_name == :$identifier || value.is_a?(Magma::TempId)

          att_name == :id ?  [:id, value ] : @model.attributes[att_name].revision_to_payload(@record_name, value, @loader.user)
        end.compact.to_h
      )
    end

    def insert_entry
      { @model.identity.column_name.to_sym => @record_name }.update(
        @record.map do |att_name,value|
          # filter out temp ids
          if att_name == :temp_id
            value.record_entry = self
            next
          end
          if att_name == :$identifier
            next
          end
          if value.is_a? Magma::TempId
            @needs_temp = true
            next
          end
          attribute_entry(att_name, value)
        end.compact.to_h
      )
    end

    def update_entry
      entry = insert_entry
      entry[:id] ||= @loader.identifier_id(@model, @record_name)

      # Never overwrite created_at.
      entry.delete(:created_at)
      entry
    end

    def temp_entry
      # Replace the entry with the appropriate values for the column.
      Hash[
        @record.map do |att_name,value|
          if att_name == :temp_id
            [ :real_id, value.real_id ]
          elsif value.is_a? Magma::TempId
            attribute_entry(att_name, value)
          else
            nil
          end
        end.compact
      ]
    end

    def attribute_key
      @record.keys
    end

    private

    def attribute_entry(att_name, value)
      return [:id, value] if att_name == :id
      @model.attributes[att_name].entry(value, @loader)
    end

    def record_exists?
      @loader.identifier_exists?(@model, @record_name)
    end

    def check_document_validity
      @complaints = []
      @loader.validator.validate(@model, @record) do |complaint|
        @complaints << complaint
      end
    end
  end
end
