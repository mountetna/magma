class Magma
  class TSVWriter
    def initialize(model, retrieval, payload)
      @model = model
      @retrieval = retrieval
      @payload = payload
    end

    def write_tsv
      @payload.add_model(@model, @retrieval.attribute_names)

      yield @payload.tsv_header(@retrieval)

      @retrieval.each_page do |records|
        @payload.add_records(@model, records)
        yield @payload.to_tsv
        @payload.reset(@model)
      end
    end
  end
end
