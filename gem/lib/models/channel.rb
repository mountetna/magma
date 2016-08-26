class Channel < Magma::Model
  parent :patient
  order :number

  attribute :antibody,
    type: String

  attribute :fluor,
    type: String

  attribute :number, 
    type: Integer,
    desc: "1-based column index of channel"
end
