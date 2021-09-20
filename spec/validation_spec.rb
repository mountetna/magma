describe Magma::Validation do
  def validate(model, record_name, document)
    @validator ||= Magma::Validation.new
    errors = []
    @validator.validate(model, record_name, document) do |error|
      errors.push error
    end
    errors
  end

  def validation_stubs
    @validation_stubs ||= {}
  end

  def stub_validation(model, att_name, new_validation)
    validation_stubs[model] ||= {}
    validation_stubs[model][att_name] = model.attributes[att_name].validation
    model.attributes[att_name].validation = new_validation
  end

  def remove_validation_stubs
    validation_stubs.each do |model,atts|
      atts.each do |att_name, old_validation|
        model.attributes[att_name].validation = old_validation
      end
    end
  end

  context 'model record validations' do
    after(:each) do
      remove_validation_stubs
    end
    
    it 'validates its own record name' do
      stub_validation(Labors::Monster, :name, {
        type: "Regexp", value: /^[A-Z][a-z]+ [A-Z][a-z]+$/
      })

      # fails
      errors = validate(Labors::Monster, 'nemean lion', labor: 'Nemean Lion')
      expect(errors).to eq(["On name, 'nemean lion' is improperly formatted."])

      # passes
      errors = validate(Labors::Monster, 'Nemean Lion', name: 'Nemean Lion', labor: 'Nemean Lion')
      expect(errors).to be_empty

      errors = validate(Labors::Monster, 'nemean lion',  name: 'Nemean Lion', labor: 'Nemean Lion')
      expect(errors).to be_empty
    end
  end

  context 'attribute validations' do
    after(:each) do
      remove_validation_stubs
    end

    it 'validates a regexp' do
      stub_validation(Labors::Monster, :species, { type: "Regexp", value: /^[a-z\s]+$/ })

      # fails
      errors = validate(Labors::Monster, 'Nemean Lion', name: 'Nemean Lion', species: 'Lion')
      expect(errors).to eq(["On species, 'Lion' is improperly formatted."])

      # passes
      errors = validate(Labors::Monster, 'Nemean Lion', name: 'Nemean Lion', species: 'lion')
      expect(errors).to be_empty

      errors = validate(Labors::Monster, 'Nemean Lion', name: 'Nemean Lion', species: [])
      expect(errors).to eq(["On species, '[]' is improperly formatted."])
    end

    it 'validates a regexp proc' do
      stub_validation(Labors::Monster, :species, {
        type: "Regexp",
        value: Proc.new { /#{2.times.map{ "[a-z\s]" }.join(" ")}/ }
      })

      # fails
      errors = validate(Labors::Monster, 'Nemean Lion', name: 'Nemean Lion', species: 'leo')
      expect(errors).to eq(["On species, 'leo' is improperly formatted."])

      # passes
      errors = validate(Labors::Monster, 'Nemean Lion', name: 'Nemean Lion', species: 'panthera leo')
      expect(errors).to be_empty
    end

    it 'validates an array' do
      stub_validation(Labors::Monster, :species, {
        type: "Array", value: ['lion', 'Panthera leo']
      })

      # fails
      errors = validate(Labors::Monster, 'Nemean Lion', name: 'Nemean Lion', species: 'Lion')
      expect(errors).to eq(["On species, 'Lion' should be one of lion, Panthera leo."])

      # passes
      errors = validate(Labors::Monster, 'Nemean Lion', name: 'Nemean Lion', species: 'lion')
      expect(errors).to be_empty
    end

    it 'validates a child identifier' do
      stub_validation(Labors::Monster, :name, {
        type: "Regexp", value: /^[A-Z][a-z]+ [A-Z][a-z]+$/
      })

      # fails
      errors = validate(Labors::Labor, 'Nemean Lion', name: 'Nemean Lion', monster: 'nemean lion')
      expect(errors).to eq(["On monster, 'nemean lion' is improperly formatted."])

      # passes
      errors = validate(Labors::Labor, 'Nemean Lion', name: 'Nemean Lion', monster: 'Nemean Lion')
      expect(errors).to be_empty
    end

    it 'validates a foreign key identifier' do
      stub_validation(Labors::Monster, :name, {
        type: "Regexp", value: /^[A-Z][a-z]+ [A-Z][a-z]+$/
      })

      # fails
      errors = validate(Labors::Victim, 'Outis Koutsonadis', name: 'Outis Koutsonadis', monster: 'nemean lion')
      expect(errors).to eq(["On monster, 'nemean lion' is improperly formatted."])

      # passes
      errors = validate(Labors::Victim, 'Outis Koutsonadis', name: 'Outis Koutsonadis', monster: 'Nemean Lion')
      expect(errors).to be_empty
    end

    it 'validates a collection' do
      stub_validation(Labors::Labor, :name, {
        type: "Regexp", value: /^[A-Z][a-z]+ [A-Z][a-z]+$/
      })

      # fails
      errors = validate(Labors::Project, 'The Three Labors of Hercules', name: 'The Three Labors of Hercules', labor: [ 'Nemean Lion', 'augean stables', 'lernean hydra' ])
      expect(errors).to eq(["On labor, 'augean stables' is improperly formatted.", "On labor, 'lernean hydra' is improperly formatted."])

      # fails
      errors = validate(Labors::Project, 'The Three Labors of Hercules', name: 'The Three Labors of Hercules', labor: 'labors.txt')
      expect(errors).to eq(["labors.txt is not an Array."])

      # passes
      errors = validate(Labors::Project,'The Three Labors of Hercules',  name: 'The Three Labors of Hercules', labor: [ 'Nemean Lion', 'Augean Stables', 'Lernean Hydra' ])
      expect(errors).to be_empty
    end

    it 'validates a match' do
      # fails
      errors = validate(
        Labors::Codex,
        'Nemean Lion',
        monster: 'Nemean Lion',
        aspect: 'hide',
        tome: 'Bullfinch',
        lore: {
          tipe: 'String',
          value: 'fur'
        }
      )
      expect(errors).to eq(
        ['{"tipe":"String","value":"fur"} is not like { type, value }.']
      )

      # passes
      errors = validate(
        Labors::Codex,
        'Nemean Lion',
        monster: 'Nemean Lion',
        aspect: 'hide',
        tome: 'Bullfinch',
        lore: {
          type: 'String',
          value: 'fur'
        }
      )
      expect(errors).to be_empty
    end

    it 'validates a range' do
      stub_validation(Labors::Labor, :number, { type: "Range", begin: 1, end: 5 })

      # fails
      errors = validate(Labors::Labor, 'Rick', name: "Rick", number: 10)
      expect(errors).to eq([
        "On number, 10 should be greater than or equal to 1 and less than or equal to 5."
      ])

      # passes
      errors = validate(Labors::Labor, 'Rick', name: "Rick", number: 3)
      expect(errors).to be_empty
    end

    it 'validates a range that excludes the end' do
      stub_validation(
        Labors::Labor,
        :number,
        { type: "Range", begin: 1, end: 5, exclude_end: true }
      )

      errors = validate(Labors::Labor, 'Rick', name: "Rick", number: 5)
      expect(errors).to eq([
        "On number, 5 should be greater than or equal to 1 and less than 5."
      ])
    end
  end

  context 'dictionary validations' do
    it 'fails to validate with an empty dictionary' do
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'hide',
        source: 'Bullfinch',
        value: 'fur'
      )

      expect(errors).to eq(['No matching entries for dictionary Labors::Codex'])
    end

    def create_codex_set(aspect, lore)
      lore.each do |monster, tomes|
        tomes.each do |tome, (lore_class, monster_lore)|
          create(
            :codex,
            monster,
            aspect: aspect,
            tome: tome.capitalize.to_s,
            lore: {
              type: lore_class,
              value: monster_lore
            }
          )
        end
      end
    end

    def build_codex
      create_codex_set(
        'hide',
        lion: { bullfinch: [ String, 'fur' ], graves: [ String, 'leather' ] },
        hydra: { bullfinch: [ String, 'scales' ], graves: [ String, 'scales' ] }
      )
      create_codex_set(
        'mass_in_stones',
        lion: { bullfinch: [ Numeric, 20000 ], graves: [ Numeric, 120 ]},
        hydra: { bullfinch: [ Numeric, 1000 ], graves: [ Numeric, 1000 ]}
      )
      create_codex_set(
        'victim_count',
        lion: { bullfinch: [ Range, [200, 300] ], graves: [ Range, [ 2000, 10000 ] ] },
        hydra: { bullfinch: [ Range, [500, 800] ], graves: [ Numeric, 205 ] }
      )
      create_codex_set(
        'cries',
        lion: { bullfinch: [ Regexp, '^[Rr]o+a+r$' ], graves: [ Array, [ 'roar', 'growl' ] ] },
        hydra: { bullfinch: [ Regexp, '^[Kk]re+a+h+$' ], graves: [ Array, [ 'hiss' ] ] }
      )
    end

    it 'validates a string match against a dictionary' do
      build_codex

      # fails
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'hide',
        source: 'Bullfinch',
        value: 'leather'
      )
      expect(errors).not_to be_empty

      # passes
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'hide',
        source: 'Bullfinch',
        value: 'fur'
      )
      expect(errors).to be_empty
    end

    it 'validates a number match against a dictionary' do
      build_codex
      # fails
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'mass_in_stones',
        source: 'Bullfinch',
        value: 150
      )
      expect(errors).not_to be_empty

      # passes
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'mass_in_stones',
        source: 'Bullfinch',
        value: 20000
      )
      expect(errors).to be_empty
    end

    it 'validates a range match against a dictionary' do
      build_codex
      # fails
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'victim_count',
        source: 'Bullfinch',
        value: 150
      )
      expect(errors).not_to be_empty

      # passes
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'victim_count',
        source: 'Bullfinch',
        value: 200
      )
      expect(errors).to be_empty
    end

    it 'validates a regexp match against a dictionary' do
      build_codex
      # fails
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'cries',
        source: 'Bullfinch',
        value: 'raooor'
      )
      expect(errors).not_to be_empty

      # passes
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'cries',
        source: 'Bullfinch',
        value: 'Roaaar'
      )
      expect(errors).to be_empty
    end

    it 'validates an array match against a dictionary' do
      build_codex
      # fails
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'cries',
        source: 'Graves',
        value: 'scream'
      )
      expect(errors).not_to be_empty

      # passes
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'cries',
        source: 'Graves',
        value: 'roar'
      )
      expect(errors).to be_empty
    end

    it 'validates against multiple entries' do
      build_codex
      # fails
      errors = validate(
        Labors::Aspect,
        'Nemean Lion',
        monster: 'Nemean Lion',
        name: 'cries',
        source: 'Graves',
        value: 'scream'
      )
      expect(errors).not_to be_empty

      # passes
      errors = validate(
        Labors::Aspect,
        'Lernean Hydra',
        monster: 'Lernean Hydra',
        name: 'cries',
        source: 'Graves',
        value: 'hiss'
      )
      expect(errors).to be_empty

      # also passes
      errors = validate(
        Labors::Aspect,
        'Lernean Hydra',
        monster: 'Lernean Hydra',
        name: 'cries',
        source: 'Bullfinch',
        value: 'Kreeaah'
      )
      expect(errors).to be_empty
    end
  end
end
