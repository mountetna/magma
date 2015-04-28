class RnaSeqBatch < Magma::Model
  identifier :batch_name
  attribute :run_date, type: DateTime
end
