class Patient < Magma::Model
  identifier :ipi_number, type: String, desc: "Unique id for patient (anonymized)"

  collection :sample
end
