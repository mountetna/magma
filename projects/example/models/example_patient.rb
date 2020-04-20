module Example
  class ExamplePatient < Magma::Model
    string :notes,
      desc: 'General notes about this patient.'
    string :physician,
      desc: 'The contact info for a patient\'s doctor.'
  end
end
