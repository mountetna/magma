class Magma
  class TSVWriter
    def initialize(model, retrieval, payload, opts={})
      @model = model
      @retrieval = retrieval
      @payload = payload

      @expand_matrices = opts[:expand_matrices]
      @transpose = opts[:transpose]
    end

    def write_tsv(&block)
      @payload.add_model(@model, @retrieval.attribute_names)
      @payload.set_predicate_manager(@retrieval.predicate_manager)
      @payload.set_options(
        expand_matrices: @expand_matrices
      )

      @transpose ?
        transpose_records(&block) :
        standard_records(&block)
    end

    def standard_records
      yield @payload.tsv_header

      @retrieval.each_page do |records|
        @payload.add_records(@model, records)
        yield @payload.to_tsv
        @payload.reset(@model)
      end
    end

    def transpose_records
      # Collect all data, then yield the transposed results
      all_data = [ tsv_row_to_array(@payload.tsv_header) ].tap do |buffer|
        @retrieval.each_page do |records|
          @payload.add_records(@model, records)
          buffer.concat(tsv_records_to_array(@payload.to_tsv))
          @payload.reset(@model)
        end
      end.transpose

      all_data.each do |row|
        yield array_to_tsv_row(row)
      end
    end

    private

    def tsv_row_to_array(row)
      # Need to set `limit` for split()
      #   to "space-pad" the resulting array
      row = row.gsub("\n", "")
      limit = row.count("\t") + 1
      row.split("\t", limit)
    end

    def tsv_records_to_array(records)
      records.split("\n").map do |record|
        tsv_row_to_array(record)
      end
    end

    def array_to_tsv_row(array)
      array.join("\t") + "\n"
    end
  end
end
