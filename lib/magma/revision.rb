class Magma
  class Revision
    attr_reader :model, :record
    attr_reader :errors

    def initialize(project_name, model_name, record_name, revised_document, validator)
      @model = Magma.instance.get_model(project_name, model_name)
      @record = @model[@model.identity => record_name]
      @revised_document = censored(revised_document || {})
      @validator = validator
    end

    def valid?
      @errors = []

      @validator.model_validator(@model).validate(@revised_document) do |error|
        @errors.push error
      end

      @errors.empty?
    end

    # Update the record using this revision.
    def post!
      @revised_document.each do |name, new_value|
        @model.attributes[name.to_sym].update @record, new_value
      end
      @record.save changed: true
      @record.refresh
    end

    private

    # Here we remove any attributes from the revised document that are set to
    # 'read only'.
    def censored(document)
      document.select do |att_name, val|
        @model.has_attribute?(att_name) && !@model.attributes[att_name.to_sym].read_only?
      end
    end
  end
end
