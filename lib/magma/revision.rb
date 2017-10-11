class Magma
  class Revision
    attr_reader :model, :record_name
    def initialize(model, record_name, revised_document, validator)
      @model = model
      @record = @model[@model.identity => record_name]
      @record_name = record_name
      @revised_document = censored(revised_document || {})
      @validator = validator
    end
    attr_reader :errors

    def valid?
      @errors = []
      @validator.model_validation(@model).validate(@revised_document) do |error|
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
        @model.attributes[name.to_sym].update @record, new_value
      end
      @record.save changed: true

      @record.refresh
    end

    private

    def censored document
      document.select do |att_name,val|
        @model.has_attribute?(att_name) && !@model.attributes[att_name.to_sym].read_only?
      end.merge(
        @model.identity => @record_name
      )
    end
  end
end
