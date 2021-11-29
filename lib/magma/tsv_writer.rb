require_relative './tsv_writer_base'

class Magma
  class TSVWriter < Magma::TSVWriterBase
    def initialize(model, retrieval, payload, opts={})
      @model = model
      @retrieval = retrieval
      @payload = payload

      super(opts)
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
  end
end
