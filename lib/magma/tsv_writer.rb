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
      @payload.set_output_format(@retrieval.output_format)
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
      [].tap do |buffer|
        buffer << tsv_row_to_array(@payload.tsv_header)

        @retrieval.each_page do |records|
          @payload.add_records(@model, records)
          buffer.concat(tsv_records_to_array(@payload.to_tsv))
          @payload.reset(@model)
        end
      end.transpose.each do |row|
        yield array_to_tsv_row(row)
      end
    end

    private

    def tsv_row_to_array(row)
      CSV.parse_line(row, col_sep: "\t")
    end

    def tsv_records_to_array(records)
      CSV.parse(records, col_sep: "\t")
    end

    def array_to_tsv_row(array)
      array.join("\t") + "\n"
    end
  end
end
