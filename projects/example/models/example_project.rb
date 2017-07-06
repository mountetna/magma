module Example
  class ExampleProject < Magma::Model
    attribute :description,
      type: String
    identifier :name,
      type:String,
      desc: 'A name for this project.'
  end
end