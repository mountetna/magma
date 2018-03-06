describe Magma::QueryController do
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

    json = json_body(last_response.body)
    expect(json[:answer].map(&:last).sort).to eq(labors.map(&:identifier).sort)
  end

  it 'generates an error for bad arguments' do
    create_list(:labor, 3)

    query(
      [ 'labor', '::ball', '::bidentifier' ]
    )

    json = json_body(last_response.body)
    expect(json[:errors]).to eq(['::ball is not a valid argument to Magma::ModelPredicate'])
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

  context Magma::Question do
    it 'returns a list of predicate definitions' do
      query('::predicates')

      json = json_body(last_response.body)
      expect(json[:predicates].keys).to include(:model, :record)
    end
  end

  context Magma::ModelPredicate do
    it 'supports ::first' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop')

      query(['prize', '::first', 'name'])

      json = json_body(last_response.body)
      expect(json[:answer]).to eq('poison')
    end

    it 'supports ::all' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop')

      query(['prize', '::all', 'name'])

      json = json_body(last_response.body)
      expect(json[:answer].map(&:last)).to eq([ 'poison', 'poop' ])
    end

    it 'supports ::any' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop', worth: 0)

      query(['prize', [ 'worth', '::>', 0 ], '::any' ])

      json = json_body(last_response.body)
      expect(json[:answer]).to eq(true)
    end

    it 'supports ::count' do
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true)
      hind = create(:labor, name: 'Ceryneian Hind', number: 3, completed: true)

      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)
      iou = create(:prize, labor: stables, name: 'iou', worth: 2)
      skin = create(:prize, labor: lion, name: 'skin', worth: 6)

      query(['labor', '::all', 'prize', '::count' ])

      json = json_body(last_response.body)
      expect(json[:answer]).to eq([
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
      
      json = json_body(last_response.body)
      expect(json[:answer].first.last).to eq('poison')
    end

    it 'supports ::lacks' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop')

      query(['prize', ['::lacks', 'worth'], '::all', 'name'])
      
      json = json_body(last_response.body)
      expect(json[:answer].first.last).to eq('poop')
    end

    it 'can retrieve metrics' do
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)

      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)
      query(['labor', '::all', '::metrics'])

      json = json_body(last_response.body)
      answer = Hash[json[:answer]]
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

      json = json_body(last_response.body)
      expect(json[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
    end

    it 'supports ::equals' do
      query(
        [ 'labor', [ 'name', '::equals', 'Nemean Lion' ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].first.last).to eq('Nemean Lion')
    end

    it 'supports ::not' do
      query(
        [ 'labor', [ 'name', '::not', 'Nemean Lion' ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].map(&:last)).to eq(['Augean Stables', 'Lernean Hydra'])
    end

    it 'supports ::in' do
      query(
        [ 'labor', [ 'name', '::in', [ 'Nemean Lion', 'Lernean Hydra' ] ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
    end

    it 'supports ::not for arrays' do
      query(
        [ 'labor', [ 'name', '::not', [ 'Nemean Lion', 'Lernean Hydra' ] ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].first.last).to eq('Augean Stables')
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

      json = json_body(last_response.body)
      expect(json[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
    end

    it 'supports ::in' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::in', [ 5, 6 ] ], '::any' ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
    end

    it 'supports ::not' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::not', [ 5, 6 ] ], '::any' ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].first.last).to eq('Augean Stables')
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

      json = json_body(last_response.body)
      expect(json[:answer].map(&:last)).to eq([ 'Augean Stables', 'Lernean Hydra' ])
    end
  end

  context Magma::VectorPredicate do
    it 'can return an arrayed result' do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)

      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)

      query(
        [ 'labor', '::all', 
          [
            [ 'number' ],
            [ 'completed' ],
            [ 'prize', '::first', 'name' ],
            [ 'prize', '::first', 'worth' ],
          ]
        ]
      )

      json = json_body(last_response.body)
      puts json[:errors] if json[:errors]
      expect(json[:answer]).to eq([
        ['Augean Stables', [5, false, 'poop', 0]],
        ['Lernean Hydra', [2, false, 'poison', 5]],
        ['Nemean Lion', [1, true, nil, nil]]
      ])
    end
  end
end
