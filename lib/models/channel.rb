class Channel < Magma::Model
  parent :stain_panel
  order :number

  attribute :antibody,
    type: String

  attribute :fluor,
    type: String

  attribute :number, 
    type: Integer,
    desc: "1-based column index of channel"
end
