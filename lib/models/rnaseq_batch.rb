class RnaSeqBatch < Magma::Model
  identifier :batch_name, type: String
  attribute :run_date, type: DateTime
end
