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
    before(:each) do
      @match_stubs = {}
    end

    def stub_match(model, att_name, new_match)
      @match_stubs[model] ||= {}
      @match_stubs[model][att_name] = model.attributes[att_name].match
      model.attributes[att_name].instance_variable_set("@match", new_match)
    end

    after(:each) do
      @match_stubs.each do |model,atts|
        atts.each do |att_name,old_match|
          model.attributes[att_name].instance_variable_set("@match",old_match)
        end
      end
    end

    it 'validates a regexp' do
      stub_match(Labors::Monster, :species, /^[a-z\s]+$/)

      # fails
      errors = validate(Labors::Monster, name: 'Nemean Lion', species: 'Lion')
      expect(errors).to eq(["On species, 'Lion' is improperly formatted."])

      # passes
      errors = validate(Labors::Monster, name: 'Nemean Lion', species: 'lion')
      expect(errors).to be_empty
    end

    it 'validates an array' do
      stub_match(Labors::Monster, :species, ['lion', 'Panthera leo'])

      # fails
      errors = validate(Labors::Monster, name: 'Nemean Lion', species: 'Lion')
      expect(errors).to eq(["On species, 'Lion' should be one of lion, Panthera leo."])

      # passes
      errors = validate(Labors::Monster, name: 'Nemean Lion', species: 'lion')
      expect(errors).to be_empty
    end

    it 'validates a child identifier' do
      stub_match(Labors::Monster, :name, /^[A-Z][a-z]+ [A-Z][a-z]+$/)

      # fails
      errors = validate(Labors::Labor, name: 'Nemean Lion', monster: 'nemean lion')
      expect(errors).to eq(["On monster, 'nemean lion' is improperly formatted."])

      # passes
      errors = validate(Labors::Labor, name: 'Nemean Lion', monster: 'Nemean Lion')
      expect(errors).to be_empty
    end

    it 'validates a foreign key identifier' do
      stub_match(Labors::Monster, :name, /^[A-Z][a-z]+ [A-Z][a-z]+$/)

      # fails
      errors = validate(Labors::Victim, name: 'Outis Koutsonadis', monster: 'nemean lion')
      expect(errors).to eq(["On monster, 'nemean lion' is improperly formatted."])

      # passes
      errors = validate(Labors::Victim, name: 'Outis Koutsonadis', monster: 'Nemean Lion')
      expect(errors).to be_empty
    end

    it 'validates a collection' do
      stub_match(Labors::Labor, :name, /^[A-Z][a-z]+ [A-Z][a-z]+$/)

      # fails
      errors = validate(Labors::Project, name: 'The Three Labors of Hercules', labor: [ 'Nemean Lion', 'augean stables', 'lernean hydra' ])
      expect(errors).to eq(["On labor, 'augean stables' is improperly formatted.", "On labor, 'lernean hydra' is improperly formatted."])

      # fails
      errors = validate(Labors::Project, name: 'The Three Labors of Hercules', labor: 'labors.txt')
      expect(errors).to eq(["labors.txt is not an Array."])

      # passes
      errors = validate(Labors::Project, name: 'The Three Labors of Hercules', labor: [ 'Nemean Lion', 'Augean Stables', 'Lernean Hydra' ])
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
