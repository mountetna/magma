class TSVWriter
  def initialize(model, retrieval, payload)
    @model = model
    @retrieval = retrieval
    @payload = payload
  end

  def write_tsv(file)
    @payload.add_model(@model, @retrieval.attribute_names)

    file << @payload.tsv_header
    @retrieval.each_page do |records|
      @payload.add_records(@model, records)
      file << @payload.to_tsv
      @payload.reset(@model)
    end

    file
  end
end
