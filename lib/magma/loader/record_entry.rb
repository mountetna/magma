class Magma
  class RecordEntry
    attr_accessor :real_id

    def initialize(model, loader)
      @record = {}
      @model = model
      @loader = loader
    end

    def <<(record)
      @record.update(record)
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

    def insert_entry
      Hash[
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
          @loader.attribute_entry(@model, att_name, value)
        end.compact
      ]
    end

    def update_entry
      entry = insert_entry
      entry[:id] ||= @loader.identifier_id(@model, identifier)

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
            @loader.send(:attribute_entry,@model, att_name, value)
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

    def identifier
      (@record[:$identifier] || @record[ @model.identity.column_name.to_sym ]).tap do |i|
        return @model.has_identifier? ? i : i.to_i
      end
    end

    def record_exists?
      @loader.identifier_exists?(@model, identifier)
    end

    def check_document_validity
      @complaints = []
      @loader.validator.validate(@model, @record) do |complaint|
        @complaints << complaint
      end
    end
  end
end
