require_relative './tsv_writer'
require_relative './retrieval'

class ModelUnloader

  def initialize(model, payload = Magma::Payload.new, retrieval = nil)
    @model = model
    @payload = payload
    @retrieval = retrieval ||
        Magma::Retrieval.new(model, nil, model.attributes.values, nil, 1, 100_000)
  end

  def tsv_dump(options = {})
    gzip = options[:gzip]
    file_dir = options[:file_dir]

    if !file_dir
      time = Time.now
      # default file_dir format e.g. "/var/tmp/project_model_2018-2-13_dump.tsv"
      file_dir = "/var/tmp/#{@model.project_name.to_s}_#{@model.model_name.to_s}_#{time.year.to_s}-#{time.month.to_s}-#{time.day.to_s}_dump.tsv"
    end

    tsv_writer = TSVWriter.new(@model, @retrieval, @payload)
    if gzip
      Zlib::GzipWriter.open("#{file_dir}.gz"){ |gz| tsv_writer.write_tsv(gz) }
    else
      open(file_dir, 'w'){ |f| tsv_writer.write_tsv(f) }
    end
  end
end
