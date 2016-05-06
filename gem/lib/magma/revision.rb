class Magma
  class Revision
    def initialize revised_document, model_name, record_name
      @model = Magma.instance.get_model model_name
      @record = @model[@model.identity => record_name]
      @revised_document = censored revised_document
    end
    attr_reader :errors

    def valid?
      @errors = []
      @revised_document.each do |name, new_value|
        name = name.to_sym
        next if !@model.has_attribute?(name) || new_value.blank?
        @model.attributes[name].validate new_value do |error|
          @errors.push error
        end
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

    def payload
      @payload ||= begin
        payload = Magma::Payload.new
        payload.add_model @model
        payload.add_records @model, [ @record ]
        payload
      end
    end

    private

    def censored document
      document.select do |att_name,val|
        @model.has_attribute?(att_name) && !@model.attributes[att_name.to_sym].read_only?
      end
    end
  end
end
