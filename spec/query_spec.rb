describe QueryController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  def query(question,user_type=:viewer)
    auth_header(user_type)
    json_post(:query, {project_name: 'labors', query: question})
  end

  it 'can post a basic query' do
    labors = create_list(:labor, 3)

    query(
      [ 'labor', '::all', '::identifier' ]
    )

    expect(json_body[:answer].map(&:last).sort).to eq(labors.map(&:identifier).sort)
  end

  it 'generates an error for bad arguments' do
    create_list(:labor, 3)

    query(
      [ 'labor', '::ball', '::bidentifier' ]
    )

    expect(json_body[:errors]).to eq(['::ball is not a valid argument to Magma::ModelPredicate'])
    expect(last_response.status).to eq(422)
  end

  it 'fails for non-users' do
    labors = create_list(:labor, 3)

    query(
      [ 'labor', '::all', '::identifier' ],
      :non_user
    )

    expect(last_response.status).to eq(403)
  end

  it 'generates a 501 error from a DB error' do
    allow_any_instance_of(Magma::Question).to receive(:answer).and_raise(Sequel::DatabaseError)

    query(
        [ 'labor', '::all', '::identifier' ]
    )

    expect(last_response.status).to eq(501)
  end

  context Magma::Question do
    it 'returns a list of predicate definitions' do
      query('::predicates')

      expect(json_body[:predicates].keys).to include(:model, :record)
    end
  end

  context Magma::ModelPredicate do
    it 'supports ::first' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop')

      query(['prize', '::first', 'name'])

      expect(json_body[:answer]).to eq('poison')
    end

    it 'supports ::all' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop')

      query(['prize', '::all', 'name'])

      expect(json_body[:answer].map(&:last)).to eq([ 'poison', 'poop' ])
    end

    it 'supports ::any' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop', worth: 0)

      query(['prize', [ 'worth', '::>', 0 ], '::any' ])

      expect(json_body[:answer]).to eq(true)
    end

    it 'supports ::count' do
      hydra = create(:labor, :hydra)
      stables = create(:labor, :stables)
      lion = create(:labor, :lion)
      hind = create(:labor, :hind)

      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)
      iou = create(:prize, labor: stables, name: 'iou', worth: 2)
      skin = create(:prize, labor: lion, name: 'skin', worth: 6)

      query(['labor', '::all', 'prize', '::count' ])

      expect(json_body[:answer]).to eq([
        [ 'Augean Stables', 2 ],
        [ 'Ceryneian Hind', 0 ],
        [ 'Lernean Hydra', 1 ],
        [ 'Nemean Lion', 1 ]
      ])
    end
  end

  context Magma::RecordPredicate do
    it 'supports ::has' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop')

      query(['prize', ['::has', 'worth'], '::all', 'name'])

      expect(json_body[:answer].count).to eq(1)
      expect(json_body[:answer].first.last).to eq('poison')
    end

    it 'supports ::lacks' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop')

      query(['prize', ['::lacks', 'worth'], '::all', 'name'])

      expect(json_body[:answer].first.last).to eq('poop')
    end

    it 'can retrieve metrics' do
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)

      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)
      query(['labor', '::all', '::metrics'])

      answer = Hash[json_body[:answer]]
      expect(answer['Lernean Hydra'][:lucrative][:score]).to eq('success')
    end
  end

  context Magma::StringPredicate do
    before(:each) do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)
    end

    it 'supports ::matches' do
      query(
        [ 'labor', [ 'name', '::matches', 'L' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
    end

    it 'supports ::equals' do
      query(
        [ 'labor', [ 'name', '::equals', 'Nemean Lion' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].first.last).to eq('Nemean Lion')
    end

    it 'supports ::not' do
      query(
        [ 'labor', [ 'name', '::not', 'Nemean Lion' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Augean Stables', 'Lernean Hydra'])
    end

    it 'supports ::in' do
      query(
        [ 'labor', [ 'name', '::in', [ 'Nemean Lion', 'Lernean Hydra' ] ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
    end

    it 'supports ::not for arrays' do
      query(
        [ 'labor', [ 'name', '::not', [ 'Nemean Lion', 'Lernean Hydra' ] ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].first.last).to eq('Augean Stables')
    end
  end

  context Magma::NumberPredicate do
    before(:each) do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)

      hide = create(:prize, labor: lion, name: 'hide', worth: 6)
      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)
    end

    it 'supports comparisons' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::!=', 0 ], '::any' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
    end

    it 'supports ::in' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::in', [ 5, 6 ] ], '::any' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
    end

    it 'supports ::not' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::not', [ 5, 6 ] ], '::any' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].first.last).to eq('Augean Stables')
    end
  end

  context Magma::DateTimePredicate do
    before(:each) do
      lion = create(:labor, name: 'Nemean Lion', number: 1, year: '02-01-0001', completed: true)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, year: '03-15-0002', completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, year: '06-07-0005', completed: false)
    end

    it 'supports comparisons' do
      query(
        [ 'labor', [ 'year', '::>', '03-01-0001' ], '::all', '::identifier' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([ 'Augean Stables', 'Lernean Hydra' ])
    end

    it 'returns in ISO8601 format' do
      query(
        [ 'labor', '::all', 'year' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(Labors::Labor.select_map(:year).map(&:iso8601))
    end
  end

  context Magma::BooleanPredicate do
    it 'checks truthiness' do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)
      query(
        [ 'labor',
          [ 'completed', '::false' ],
          '::all',
          'name'
        ]
      )

      expect(json_body[:answer].map(&:last)).to eq([ 'Augean Stables', 'Lernean Hydra' ])
    end
  end

  context Magma::TablePredicate do
    it 'can return an arrayed result' do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)

      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)

      query(
        [ 'labor', '::all',

          # The table argument
          [
            [ 'number' ],
            [ 'completed' ],

            # three separate rows with the same filter
            # allows us to test for the presence of empty
            # (nil) cells
            [ 'prize', [ 'name', '::equals', 'poison' ], '::first', 'worth' ],
            [ 'prize', [ 'name', '::equals', 'poop' ], '::first', 'worth' ],
            [ 'prize', [ 'name', '::equals', 'hide' ], '::first', 'worth' ]
          ]
        ]
      )

      expect(json_body[:answer]).to eq( [
        ['Augean Stables', [5, false, nil, 0, nil]],
        ['Lernean Hydra', [2, false, 5, nil, nil]],
        ['Nemean Lion', [1, true, nil, nil, nil]]
      ])
    end
  end

  context 'restriction' do
    it 'hides restricted records' do
      restricted_victim_list = create_list(:victim, 9, restricted: true)
      unrestricted_victim_list = create_list(:victim, 9)

      query(
        [ 'victim', '::all',
          [
            [ '::identifier' ]
          ]
        ]
      )
      expect(json_body[:answer].map(&:first).sort).to eq(unrestricted_victim_list.map(&:identifier))
    end

    it 'shows restricted records to people with permissions' do
      restricted_victim_list = create_list(:victim, 9, restricted: true)
      unrestricted_victim_list = create_list(:victim, 9)

      query(
        [ 'victim', '::all',
          [
            [ '::identifier' ]
          ]
        ],
        :editor
      )
      # the editor has a restricted permission
      expect(json_body[:answer].map(&:first).sort).to eq(
        (
          restricted_victim_list.map(&:identifier) +
          unrestricted_victim_list.map(&:identifier)
        ).sort
      )
    end

    it 'prevents queries on restricted attributes' do
      victim_list = create_list(:victim, 9, country: 'thrace')

      query([ 'victim', '::all', 'country' ])
      expect(last_response.status).to eq(403)
    end

    it 'allows queries on restricted attributes to users with restricted permission' do
      victim_list = create_list(:victim, 9, country: 'thrace')

      query([ 'victim', '::all', 'country' ], :editor)
      expect(json_body[:answer].map(&:last).sort).to all(eq('thrace'))
    end
  end
end
