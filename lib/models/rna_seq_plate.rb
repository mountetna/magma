class RnaSeqPlate < Magma::Model
  identifier :plate_name, type: String, match: /Plate[\w]+/
  collection :rna_seq

  attribute :submission_date, type: DateTime
  attribute :library_prep, type: String
end
