module Example
  class ExamplePatient < Magma::Model
    attribute :notes,
      type: String,
      desc: 'General notes about this patient.'
    attribute :physician, 
      type: String, 
      desc: 'The contact info for a patient\'s doctor.'
  end
end
