module Example
  class ExamplePatient < Magma::Model
    string :notes,
      description: 'General notes about this patient.'
    string :physician,
      description: 'The contact info for a patient\'s doctor.'
  end
end
