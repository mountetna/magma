class Magma
  class RecordEntry
    attr_accessor :real_id

    attr_reader :record_name

    def initialize(model, record_name, loader)
      @model = model
      @record_name = record_name
      @loader = loader
      @record = {}

      set_temp_id
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

    def []=(att_name, value)
      raise ArgumentError, "#{att_name} cannot be re-assigned." unless shifted_date_time_attribute_names.include?(att_name)
      raise ArgumentError, "Can only re-assign a DateTime to #{att_name}." unless value.is_a?(DateTime)

      @record[att_name] = value
    end

    def has_key?(att_name)
      @record.has_key?(att_name)
    end

    def complaints
      return @complaints if @complaints
      check_document_validity
      check_record_name_validity unless record_exists?
      check_date_shift_validity if requires_date_shifting

      return @complaints.uniq
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

    def requires_date_shifting
      attribute_key.any? do |attr|
        shifted_date_time_attribute_names.include?(attr)
      end
    end

    def shifted_date_time_attribute_names
      @shifted_date_time_attribute_names ||= @model.date_shift_attributes.map(&:name)
    end

    def needs_temp?
      @needs_temp ||= @record.any? do |att_name, value|
        attribute = @model.attributes[att_name]
        attribute.is_a?(Magma::ForeignKeyAttribute) &&
          !@loader.identifier_exists?(attribute.link_model, value)
      end
    end

    def payload_entry
      { @model.identity.name => @record_name }.update(
        @record.map do |att_name,value|
          att_name == :id ?  [:id, value ] : @model.attributes[att_name].revision_to_payload(@record_name, value, @loader)
        end.compact.to_h
      )
    end

    def insert_entry
      entry = {}

      id_column = @model.identity.column_name.to_sym

      entry[id_column] = @record_name unless id_column == :id

      entry.update(
        @record.map do |att_name,value|
          # filter out temp ids
          next if value.is_a?(Magma::TempId)
          attribute_entry(att_name, value)
        end.compact.to_h
      )

      # With multi-insert, the timestamp Sequel plugin doesn't automatically
      #   add these values.
      entry[:created_at] = Time.now
      entry[:updated_at] = Time.now

      entry
    end

    def update_entry
      entry = insert_entry
      entry[:id] ||= @loader.identifier_id(@model, @record_name)

      # Never overwrite created_at.
      entry.delete(:created_at)

      # Set updated_at
      entry[:updated_at] = Time.now
      entry
    end

    def temp_entry
      # Replace the entry with the appropriate values for the column.
      @record.map do |att_name,value|
        attribute = @model.attributes[att_name]
        next unless attribute.is_a?(Magma::ForeignKeyAttribute)
        [ attribute.foreign_id, @loader.identifier_id(attribute.link_model, value).real_id ]
      end.compact.to_h.merge(
        real_id: @loader.real_id(@model, @record_name)
      )
    end

    def attribute_key
      @record.keys
    end

    def includes_parent_record?
      attribute_key.include?(parent_attribute_name)
    end

    def parent_record_name
      return nil unless includes_parent_record?

      self[parent_attribute_name]
    end

    private

    def set_temp_id
      id = @loader.identifier_id(@model, @record_name)

      if id.is_a?(Magma::TempId)
        id.record_entry = self
      end
    end

    def attribute_entry(att_name, value)
      return [:id, value] if att_name == :id
      @model.attributes[att_name].entry(value, @loader)
    end

    def record_exists?
      @loader.identifier_exists?(@model, @record_name)
    end

    def check_document_validity
      @complaints = []
      @loader.validator.validate(@model, @record_name, @record) do |complaint|
        @complaints << complaint
      end
    end

    def check_record_name_validity
      # On create, make sure the record_name is valid
      @loader.validator.validate(@model, @record_name, {
        identifier_attribute_name => @record_name
      }) do |complaint|
        @complaints << complaint
      end
    end

    def check_date_shift_validity
      # If the loader says there is some other path to
      #   the date_shift_root model, then we're also okay.
      return if @loader.is_connected_to_date_shift_root?(@model, self.record_name)

      complaints << "Cannot execute action on #{record_name}, because it is not connected to the date_shift_root model, but requires date-shifting."
    end

    def identifier_attribute_name
      @model.attributes.values.select do |attribute|
        attribute.is_a?(Magma::IdentifierAttribute)
      end.first.name.to_sym
    end

    def parent_attribute_name
      @model.attributes.values.select do |attribute|
        attribute.is_a?(Magma::ParentAttribute)
      end.first.name.to_sym
    end
  end
end
