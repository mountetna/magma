module Example
  class ExampleProject < Magma::Model
    string :description
    identifier :name,
      type:String,
      desc: 'A name for this project.'
  end
end
