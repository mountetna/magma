class Magma
  class Revision
    attr_reader :model, :record
    def initialize(revised_document, model_name, record_name, validator)
      @model = Magma.instance.get_model model_name
      @record = @model[@model.identity => record_name]
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
      end
    end
  end
end
