module Example
  class ExampleProject < Magma::Model
    string :description
    identifier :name,
      type:String,
      description: 'A name for this project.'
  end
end
