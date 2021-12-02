class Magma
  class TSVError < StandardError
  end

  class TSVWriterBase
    def initialize(opts = {})
      @expand_matrices = opts[:expand_matrices]
      @transpose = opts[:transpose]
    end

    def write_tsv(&block)
      raise "Subclasses should implement this."
    end

    private

    def tsv_row_to_array(row)
      CSV.parse_line(row, col_sep: "\t", quote_char: "|")
    end

    def tsv_records_to_array(records)
      # Add a non-standard quote_char to avoid issues with
      #   JSON-stringified cells in our records.
      CSV.parse(records, col_sep: "\t", quote_char: "|")
    end

    def array_to_tsv_row(array)
      array.join("\t") + "\n"
    end
  end
end
