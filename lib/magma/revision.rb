class Magma
  class Revision
    attr_reader :model, :record_name
    def initialize(model, record_name, revised_document, validator, restrict)
      @model = model
      @record = @model[@model.identity => record_name]
      @record_name = record_name
      @revised_document = censored(revised_document || {})
      @validator = validator
      @restrict = restrict
    end
    attr_reader :errors

    def updated_record
      @updated_record ||= { @model.identity => final_record_name }
    end

    def final_record_name
      @model.identity == :id ? @record.id : @revised_document[@model.identity]
    end

    def valid?
      @errors = []

      if @restrict
        if @model.has_attribute?(:restricted) && @record[:restricted]
          @errors.push "Cannot revise restricted #{@model.model_name} '#{@record.identifier}'"
        end
        @revised_document.each do |attribute_name, value|
          if @model.has_attribute?(attribute_name) && @model.attributes[attribute_name].restricted
            @errors.push "Cannot revise restricted attribute :#{ attribute_name } on #{@model.model_name} '#{@record.identifier}'"
          end
        end
      end

      @validator.validate(@model, @revised_document) do |error|
        @errors.push error
      end

      @errors.empty?
    end

    def attribute_names
      @revised_document.keys
    end

    def post!
      # update the record using this revision
      @revised_document.each do |name, new_value|
        updated_record[name.to_sym] = @model.attributes[name.to_sym].update_record(@record, new_value)
      end
      @record.save changed: true

      @record.refresh
    end

    private

    def censored document
      {
        @model.identity => @record_name
      }.merge(document).select do |att_name,val|
        @model.has_attribute?(att_name) && !@model.attributes[att_name.to_sym].read_only?
      end
    end
  end
end
