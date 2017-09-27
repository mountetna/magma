describe Magma::Server::Query do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  def query(question)
    json_post(:query, {project_name: 'labors', query: question})
  end

  context 'Magma::RecordPredicate' do
    it 'supports ::has' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop')

      query(['prize', ['::has', 'worth'], '::all', 'name'])
      
      json = json_body(last_response.body)
      expect(json[:answer].first.last).to eq('poison')
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

  context 'Magma::StringPredicate' do
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
      expect(json[:answer].length).to eq(2)
    end

    it 'supports ::equals' do
      query(
        [ 'labor', [ 'name', '::equals', 'Nemean Lion' ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].length).to eq(1)
    end

    it 'supports ::in' do
      query(
        [ 'labor', [ 'name', '::in', [ 'Nemean Lion', 'Lernean Hydra' ] ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].length).to eq(2)
    end
  end

  context 'Magma::NumberPredicate' do
    before(:each) do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)

      hide = create(:prize, labor: lion, name: 'hide', worth: 5)
      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)
    end
    it 'supports >, <, >=, <=' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::>', 2 ], '::first', 'worth', '::>', 2 ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].length).to eq(2)
    end
    it 'supports in' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::in', [ 5 ] ], '::first', 'worth', '::in', [ 5 ] ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].length).to eq(2)
    end
  end

  context "Magma::NumberPredicate" do
    before(:each) do
      lion = create(:labor, name: "Nemean Lion", number: 1, completed: true)
      hydra = create(:labor, name: "Lernean Hydra", number: 2, completed: false)
      stables = create(:labor, name: "Augean Stables", number: 5, completed: false)

      hide = create(:prize, labor: lion, name: "hide", worth: 5)
      poison = create(:prize, labor: hydra, name: "poison", worth: 5)
      poop = create(:prize, labor: stables, name: "poop", worth: 0)
    end
    it "supports >, <, >=, <=" do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::>', 2 ], '::first', 'worth', '::>', 2 ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].length).to eq(2)
    end
    it "supports in" do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::in', [ 5 ] ], '::first', 'worth', '::in', [ 5 ] ], '::all', '::identifier' ]
      )

      json = json_body(last_response.body)
      expect(json[:answer].length).to eq(2)
    end
  end

  it "can post a basic query" do
    create_list(:labor, 3)

    query(
      [ 'labor', '::all', '::identifier' ]
    )

    json = json_body(last_response.body)
    expect(json[:answer].length).to eq(3)
  end

  it "can return an arrayed result" do
    lion = create(:labor, name: "Nemean Lion", number: 1, completed: true)
    hydra = create(:labor, name: "Lernean Hydra", number: 2, completed: false)
    stables = create(:labor, name: "Augean Stables", number: 5, completed: false)

    poison = create(:prize, labor: hydra, name: "poison", worth: 5)
    poop = create(:prize, labor: stables, name: "poop", worth: 0)

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

    json = JSON.parse(last_response.body)
    puts json["errors"] if json["errors"]
    expect(json["answer"]).to eq([
      ["Augean Stables", [5, false, "poop", 0]],
      ["Lernean Hydra", [2, false, "poison", 5]],
      ["Nemean Lion", [1, true, nil, nil]]
    ])
  end
end
