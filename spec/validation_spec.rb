describe Magma::Validation do
  def validate(model, document)
    @validator ||= Magma::Validation.new
    errors = []
    @validator.validate(model,document) do |error|
      errors.push error
    end
    errors
  end

  context 'attribute validations' do
    def set_match(new_match)
      @orig_match = Labors::Monster.attributes[:species].match
      Labors::Monster.attributes[:species].instance_variable_set("@match", new_match)
    end

    after(:each) do
      Labors::Monster.attributes[:species].instance_variable_set("@match", @orig_match)
    end

    it 'validates a regexp' do
      set_match(/^[a-z\s]+$/)

      # fails
      errors = validate(Labors::Monster, name: 'Nemean Lion', species: 'Lion')
      expect(errors).to eq(["On species, 'Lion' is improperly formatted."])

      # passes
      errors = validate(Labors::Monster, name: 'Nemean Lion', species: 'lion')
      expect(errors).to be_empty
    end

    it 'validates an array' do
      set_match(['lion', 'Panthera leo'])

      # fails
      errors = validate(Labors::Monster, name: 'Nemean Lion', species: 'Lion')
      expect(errors).to eq(["On species, 'Lion' should be one of lion, Panthera leo."])

      # passes
      errors = validate(Labors::Monster, name: 'Nemean Lion', species: 'lion')
      expect(errors).to be_empty
    end
  end

  it 'fails to validate with an empty dictionary' do
    lion = create(:monster, :lion)
    hydra = create(:monster, name: 'Lernean Hydra', species: 'hydra')

    errors = validate(
      Labors::Aspect,
      name: 'hide',
      source: 'Bullfinch',
      value: 'fur'
    )

    expect(errors).not_to be_empty
  end
end
