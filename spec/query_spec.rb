describe QueryController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    route_payload = JSON.generate([
      {:method=>"POST", :route=>"/:project_name/find/:bucket_name", :name=>"bucket_find", :params=>["project_name", "bucket_name"]}
    ])
    stub_request(:options, 'https://metis.test').
    to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})

    #stub_request(:any, /https:\/\/metis.test/).
      #to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})
    @project = create(:project, name: 'The Twelve Labors of Hercules')
  end

  def query(question,user_type=:viewer,opts={})
    auth_header(user_type)
    json_post(:query, {project_name: 'labors', query: question}.update(opts))
  end

  def query_opts(question,opts={})
    query(question, :viewer, opts)
  end

  def update(revisions, user_type=:editor)
    auth_header(user_type)
    json_post(:update, {project_name: 'labors', revisions: revisions})
  end

  it 'can post a basic query' do
    labors = create_list(:labor, 3, project: @project)

    query(
      [ 'labor', '::all', '::identifier' ]
    )

    expect(last_response.status).to eq(200)
    expect(json_body[:answer].map(&:last).sort).to eq(labors.map(&:identifier).sort)
    expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
  end

  it 'generates an error for bad arguments' do
    create_list(:labor, 3)

    query(
      [ 'labor', '::ball', '::bidentifier' ]
    )

    expect(json_body[:errors]).to eq(['::ball is not a valid argument to Magma::StartPredicate'])
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

  context 'disconnected data' do
    it 'hides disconnected records by default' do
      labors = create_list(:labor, 3, project: @project)
      disconnected_labors = create_list(:labor, 3)

      query(
        [ 'labor', '::all', '::identifier' ]
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map(&:last).sort).to eq(labors.map(&:identifier).sort)
    end

    it 'shows only disconnected records if asked' do
      labors = create_list(:labor, 3, project: @project)
      disconnected_labors = create_list(:labor, 3)

      auth_header(:viewer)
      json_post(:query,
        project_name: 'labors',
        query: [ 'labor', '::all', '::identifier' ],
        show_disconnected: true
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map(&:last).sort).to match_array((disconnected_labors).map(&:identifier))
    end
  end

  context Magma::ModelPredicate do
    before(:each) do
      @hydra = create(:labor, :hydra, project: @project)
      @stables = create(:labor, :stables, project: @project)
      @lion = create(:labor, :lion, project: @project)
      @hind = create(:labor, :hind, project: @project)
    end

    context 'filtering' do
      it 'allows filters' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)

        query(['prize', [ 'worth', '::>=', 5 ], '::all', 'name'])

        expect(last_response.status).to eq(200)
        expect(json_body[:answer].first.last).to eq('poison')
        expect(json_body[:format]).to eq([ 'labors::prize#id', 'labors::prize#name' ])
      end

      it 'combines filters' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)
        iou = create(:prize, name: 'iou', worth: 5, labor: @hind)
        skin = create(:prize, name: 'skin', worth: 2, labor: @lion)

        query(['prize', [ 'name', '::matches', '^po' ], [ 'worth', '::>=', 5 ], '::all', 'name'])

        expect(last_response.status).to eq(200)
        expect(json_body[:answer].first.last).to eq('poison')
        expect(json_body[:format]).to eq([ 'labors::prize#id', 'labors::prize#name' ])
      end

      it 'combines filters with ::or' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)
        iou = create(:prize, name: 'iou', worth: 5, labor: @hind)
        skin = create(:prize, name: 'skin', worth: 2, labor: @lion)

        query(['prize', [ '::or', [ 'name', '::matches', '^po' ], [ 'worth', '::>=', 5 ] ], '::all', 'name'])

        expect(last_response.status).to eq(200)
        expect(json_body[:answer].map(&:last)).to match_array([ 'poop', 'poison', 'iou' ])
        expect(json_body[:format]).to eq([ 'labors::prize#id', 'labors::prize#name' ])
      end

      it 'combines several ::and filters with ::or' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)
        iou = create(:prize, name: 'iou', worth: 5, labor: @hind)
        skin = create(:prize, name: 'skin', worth: 2, labor: @lion)

        query(['prize', [ '::or',
            [ '::and', [ 'name', '::matches', '^po' ], [ 'worth', '::>=', 5 ] ],
            [ '::and', [ 'name', '::matches', 'i' ], [ 'worth', '::=', 2 ] ]
          ], '::all', 'name'])

        expect(last_response.status).to eq(200)
        expect(json_body[:answer].map(&:last)).to match_array([ 'skin', 'poison' ])
        expect(json_body[:format]).to eq([ 'labors::prize#id', 'labors::prize#name' ])
      end

      it 'combines several ::or filters with ::and' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)
        iou = create(:prize, name: 'iou', worth: 5, labor: @hind)
        skin = create(:prize, name: 'skin', worth: 2, labor: @lion)

        query(['prize', [ '::and',
            [ '::or', [ 'name', '::matches', '^po' ], [ 'worth', '::>=', 5 ] ],
            [ '::or', [ 'name', '::matches', 'on$' ], [ 'worth', '::<=', 2 ] ]
          ], '::all', 'name'])

        expect(last_response.status).to eq(200)
        expect(json_body[:answer].map(&:last)).to match_array([ 'poison' ])
        expect(json_body[:format]).to eq([ 'labors::prize#id', 'labors::prize#name' ])
      end

      it 'combines several ::or filters' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)
        iou = create(:prize, name: 'iou', worth: 5, labor: @hind)
        skin = create(:prize, name: 'skin', worth: 2, labor: @lion)

        query(['prize', 
            [ '::or', [ 'name', '::matches', '^po' ], [ 'worth', '::>=', 5 ] ],
            [ '::or', [ 'name', '::matches', 'on$' ], [ 'worth', '::<=', 2 ] ],
            '::all', 'name'])

        expect(last_response.status).to eq(200)
        expect(json_body[:answer].map(&:last)).to match_array([ 'poison' ])
        expect(json_body[:format]).to eq([ 'labors::prize#id', 'labors::prize#name' ])
      end
    end

    it 'supports ::first' do
      poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
      poop = create(:prize, name: 'poop', labor: @stables)

      query(['prize', '::first', 'name'])

      expect(json_body[:answer]).to eq('poison')
      expect(json_body[:format]).to eq('labors::prize#name')
    end

    it 'supports ::all' do
      poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
      poop = create(:prize, name: 'poop', labor: @stables)

      query(['prize', '::all', 'name'])

      expect(json_body[:answer].map(&:last)).to eq([ 'poison', 'poop' ])
      expect(json_body[:format]).to eq([ 'labors::prize#id', 'labors::prize#name' ])
    end

    context 'with conditional subqueries' do
      it 'supports ::every with ::has as filter' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 2)
        skin = create(:prize, labor: @lion, name: 'skin', worth: 1)

        query(['labor', ['prize', ['::has', 'worth'], '::every'], '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Lernean Hydra", "Nemean Lion" ])
        expect(json_body[:format]).to eq([ "labors::labor#name", "labors::labor#name" ])
      end

      it 'supports ::every with attribute value as filter' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 2)
        skin = create(:prize, labor: @lion, name: 'skin', worth: 1)

        query(['labor', ['prize', ['worth', '::>', 3], '::every'], '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Lernean Hydra" ])
        expect(json_body[:format]).to eq([ "labors::labor#name", "labors::labor#name" ])
      end

      it 'supports ::every as boolean' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', worth: 0, labor: @stables)

        query(['prize', [ 'worth', '::>', 10 ], '::every' ])

        expect(json_body[:answer]).to eq(false)
        expect(json_body[:format]).to eq('Boolean')

        query(['prize', [ 'worth', '::<', 10 ], '::every' ])
        expect(json_body[:answer]).to eq(true)
      end

      it 'supports ::any as boolean' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', worth: 0, labor: @stables)

        query(['prize', [ 'worth', '::>', 0 ], '::any' ])

        expect(json_body[:answer]).to eq(true)
        expect(json_body[:format]).to eq('Boolean')
      end

      it 'supports ::any with ::has as filter' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 2)
        skin = create(:prize, labor: @lion, name: 'skin')

        query(['labor', ['prize', ['::has', 'worth'], '::any'], '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Augean Stables", "Lernean Hydra" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      end

      it 'supports ::any with attribute value as filter' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 2)
        skin = create(:prize, labor: @lion, name: 'skin')

        query(['labor', ['prize', ['worth', '::>', 3], '::any'], '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Lernean Hydra" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      end

      it 'supports combinations of ::any and ::every' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 2)
        skin = create(:prize, labor: @lion, name: 'skin')

        query(['labor',
              ['prize', ['worth', '::>', 3], '::any'],
              ['prize', ['::has', 'worth'], '::every'],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Augean Stables", "Lernean Hydra" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      end

      it 'supports ::and and ::any filters on single model' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 4)
        skin = create(:prize, labor: @lion, name: 'skin')

        query(['labor',
              ['prize', ['::and', ['worth', '::>', 3], ['worth', '::<', 6]], '::any'],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Augean Stables", "Lernean Hydra" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      
        query(['labor',
          ['prize', ['::and', ['worth', '::>', 3], ['worth', '::<', 6]], '::every'],
          '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Lernean Hydra" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      end

      it 'supports ::and and ::any filters across multiple models' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 4)
        skin = create(:prize, labor: @lion, name: 'skin')

        lion_monster = create(:monster, :lion, labor: @lion)
        hydra_monster = create(:monster, :hydra, labor: @hydra)

        query(['labor',
              ['::and',
                ['prize', ['::or', ['worth', '::>', 6], ['worth', '::<', 3]], '::any'],
                ['monster', 'name', '::matches', 'Ne']
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      
        query(['labor',
              ['::and',
                ['prize', ['::or', ['worth', '::<', 6], ['worth', '::>', 10]], '::every'],
                ['monster', 'name', '::matches', 'ean']
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Lernean Hydra"])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      end

      it 'supports multiple conditional filters with ::and, across multiple models' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 4)
        skin = create(:prize, labor: @lion, name: 'skin')

        lion_monster = create(:monster, :lion, labor: @lion)
        hydra_monster = create(:monster, :hydra, labor: @hydra)

        john_doe = create(:victim, name: 'John Doe', monster: lion_monster, country: 'Italy')
        jane_doe = create(:victim, name: 'Jane Doe', monster: lion_monster, country: 'Greece')
  
        query(['labor',
              ['::and',
                ['prize', ['::lacks', 'worth'], '::any'],
                ['monster', 'victim', ['name', '::matches', 'John'], '::any'],
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Nemean Lion" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
        
        query(['labor',
              ['::and',
                ['prize', ['::lacks', 'worth'], '::any'],
                ['monster', 'victim', ['name', '::matches', 'John'], '::every'],
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      end

      it 'supports ::or and ::any filters on single model' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 4)
        skin = create(:prize, labor: @lion, name: 'skin')

        query(['labor',
          ['prize', ['::or', ['worth', '::>', 6], ['worth', '::<', 3]], '::any'],
          '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Augean Stables" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      end

      it 'supports ::or and ::any filters across multiple models' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 4)
        skin = create(:prize, labor: @lion, name: 'skin')

        lion_monster = create(:monster, :lion, labor: @lion)
        hydra_monster = create(:monster, :hydra, labor: @hydra)

        query(['labor',
              ['::or',
                ['prize', ['::or', ['worth', '::>', 6], ['worth', '::<', 3]], '::any'],
                ['monster', 'name', '::matches', 'Ne']
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Augean Stables", "Nemean Lion" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
  
        query(['labor',
              ['::or',
                ['prize', ['::or', ['worth', '::>', 6], ['worth', '::<', 3]], '::every'],
                ['monster', 'name', '::matches', 'Ne']
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Nemean Lion" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])    
      end

      it 'supports multiple ::any filters within an ::or filter across multiple models' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 4)
        skin = create(:prize, labor: @lion, name: 'skin')

        lion_monster = create(:monster, :lion, labor: @lion)
        hydra_monster = create(:monster, :hydra, labor: @hydra)

        john_doe = create(:victim, name: 'John Doe', monster: lion_monster, country: 'Italy')
        jane_doe = create(:victim, name: 'Jane Doe', monster: lion_monster, country: 'Greece')
      
        query(['labor',
              ['::or',
                ['prize', ['::has', 'worth'], '::any'],
                ['monster', 'victim', ['name', '::matches', 'John'], '::any'],
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Augean Stables", "Lernean Hydra", "Nemean Lion" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
        
        query(['labor',
              ['::or',
                ['prize', ['::has', 'worth'], '::any'],
                ['monster', 'victim', ['name', '::matches', 'John'], '::every'],
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Augean Stables", "Lernean Hydra" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      end

      it 'rejects invalid filters' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 2)
        skin = create(:prize, labor: @lion, name: 'skin')

        query(['labor',
          ['prize', ["' OR '1'='1' -- haha!", '::=', 'drop something'], '::any'],
          '::all', '::identifier'])

        expect(last_response.status).to eq(422)
      end

      it 'supports arbitrary depth' do
        poison = create(:prize, name: 'poison', worth: 7, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 4)
        skin = create(:prize, labor: @lion, name: 'skin')

        lion_monster = create(:monster, :lion, labor: @lion)
        hydra_monster = create(:monster, :hydra, labor: @hydra)

        john_doe = create(:victim, name: 'John Doe', monster: lion_monster, country: 'Italy')
        jane_doe = create(:victim, name: 'Jane Doe', monster: lion_monster, country: 'Greece')
      
        query(['labor',
              ['::and',
                ['::or',
                  ['prize', ['::lacks', 'worth'], '::every'],
                  ['prize', ['worth', '::<', 6], '::any']
                ],
                ['::or',
                  ['monster', 'victim', ['name', '::matches', 'John'], '::any'],
                  ['name', '::matches', 'dra']
                ]
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Nemean Lion" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      
        query(['labor',
              ['::or',
                ['::or',
                  ['prize', ['::lacks', 'worth'], '::every'],
                  ['prize', ['worth', '::<', 6], '::any']
                ],
                ['::or',
                  ['monster', 'victim', ['name', '::matches', 'John'], '::any'],
                  ['name', '::matches', 'dra']
                ]
              ],
              '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Augean Stables", "Lernean Hydra", "Nemean Lion" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      
      end

      it 'works with filters across multiple models' do
        poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
        poop = create(:prize, name: 'poop', labor: @stables, worth: 8)
        iou = create(:prize, labor: @stables, name: 'iou', worth: 4)
        skin = create(:prize, labor: @lion, name: 'skin')

        lion_monster = create(:monster, :lion, labor: @lion)
        hydra_monster = create(:monster, :hydra, labor: @hydra)

        john_doe = create(:victim, name: 'John Doe', monster: lion_monster, country: 'Italy')
        jane_doe = create(:victim, name: 'Jane Doe', monster: lion_monster, country: 'Greece')

        query(['labor',
          ['prize', ['::or', ['worth', '::>', 6], ['worth', '::<', 3]], '::any'],
          ['monster', 'name', '::matches', 'Ne'],
          '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      
        query(['labor',
          ['prize', ['::lacks', 'worth'], '::any'],
          ['monster', 'victim', ['name', '::matches', 'John'], '::any'],
          '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ "Nemean Lion" ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
        
        query(['labor',
          ['prize', ['::lacks', 'worth'], '::any'],
          ['monster', 'victim', ['name', '::matches', 'John'], '::every'],
          '::all', '::identifier'])

        expect(json_body[:answer].map(&:last)).to eq([ ])
        expect(json_body[:format]).to eq([ 'labors::labor#name', 'labors::labor#name' ])
      end
    end

    it 'supports ::count' do
      poison = create(:prize, labor: @hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: @stables, name: 'poop', worth: 0)
      iou = create(:prize, labor: @stables, name: 'iou', worth: 2)
      skin = create(:prize, labor: @lion, name: 'skin', worth: 6)

      query(['labor', '::all', 'prize', '::count' ])

      expect(json_body[:answer]).to eq([
        [ 'Augean Stables', 2 ],
        [ 'Ceryneian Hind', 0 ],
        [ 'Lernean Hydra', 1 ],
        [ 'Nemean Lion', 1 ]
      ])
      expect(json_body[:format]).to eq(['labors::labor#name', 'Numeric'])
    end

    it 'supports ::count and ::any' do 
      poison = create(:prize, labor: @hydra, name: 'poison', worth: 0)
      poop = create(:prize, labor: @stables, name: 'poop', worth: 4)
      iou = create(:prize, labor: @stables, name: 'iou', worth: 3)
      skin = create(:prize, labor: @lion, name: 'skin', worth: 5)

      query(['labor', ['prize', [ 'worth', '::>', 0 ], '::any'], '::count' ])

      expect(json_body[:answer]).to eq(2)
      expect(json_body[:format]).to eq('Numeric')
    end

    it 'supports ::count and ::every' do 
      poison = create(:prize, labor: @hydra, name: 'poison', worth: 0)
      poop = create(:prize, labor: @stables, name: 'poop', worth: 4)
      iou = create(:prize, labor: @stables, name: 'iou', worth: 3)
      skin = create(:prize, labor: @lion, name: 'skin', worth: 5)

      query(['labor', ['prize', [ 'worth', '::>', 3 ], '::every'], '::count' ])

      expect(json_body[:answer]).to eq(1)
      expect(json_body[:format]).to eq('Numeric')
    end
  end

  context Magma::RecordPredicate do
    before(:each) do
      @hydra = create(:labor, :hydra, project: @project)
      @stables = create(:labor, :stables, project: @project)
    end

    it 'supports ::has' do
      poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
      poop = create(:prize, name: 'poop', labor: @stables)

      query(['prize', ['::has', 'worth'], '::all', 'name'])

      expect(json_body[:answer].count).to eq(1)
      expect(json_body[:answer].first.last).to eq('poison')
      expect(json_body[:format]).to eq(['labors::prize#id', 'labors::prize#name'])
    end

    it 'supports ::lacks' do
      poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
      poop = create(:prize, name: 'poop', labor: @stables)

      query(['prize', ['::lacks', 'worth'], '::all', 'name'])

      expect(json_body[:answer].first.last).to eq('poop')
      expect(json_body[:format]).to eq(['labors::prize#id', 'labors::prize#name'])
    end

    it 'can retrieve metrics' do
      poison = create(:prize, labor: @hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: @stables, name: 'poop', worth: 0)
      query(['labor', '::all', '::metrics'])

      answer = Hash[json_body[:answer]]
      expect(answer['Lernean Hydra'][:lucrative][:score]).to eq('success')
    end
  end

  context Magma::StringPredicate do
    before(:each) do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true, notes: "tough", project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false, notes: "fun", project: @project)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false, project: @project)

      @lion_difficulty = create(:characteristic, labor: lion, name: "difficulty", value: "10" )
      @hydra_difficulty = create(:characteristic, labor: hydra, name: "difficulty", value: "2" )
      @stables_difficulty = create(:characteristic, labor: stables, name: "difficulty", value: "5.1" )
    
      lion_stance = create(:characteristic, labor: lion, name: "stance", value: "wrestling" )
      hydra_stance = create(:characteristic, labor: hydra, name: "stance", value: "hacking" )
      stables_stance = create(:characteristic, labor: stables, name: "stance", value: "shoveling" )
    end

    it 'supports ::matches' do
      query(
        [ 'labor', [ 'name', '::matches', 'L' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'supports ::equals' do
      query(
        [ 'labor', [ 'name', '::equals', 'Nemean Lion' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].first.last).to eq('Nemean Lion')
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'supports ::not' do
      query(
        [ 'labor', [ 'name', '::not', 'Nemean Lion' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Augean Stables', 'Lernean Hydra'])
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'supports ::in' do
      query(
        [ 'labor', [ 'name', '::in', [ 'Nemean Lion', 'Lernean Hydra' ] ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'supports ::not for arrays' do
      query(
        [ 'labor', [ 'name', '::not', [ 'Nemean Lion', 'Lernean Hydra' ] ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].first.last).to eq('Augean Stables')
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'supports ::> for numeric strings' do
      query(
        [ 'characteristic', [ "name", "::matches", "difficulty" ], ["value", "::>", "5.1"], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map { |a| a.last }).to eq([@lion_difficulty.id])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])

      query(
        [ 'characteristic', [ "name", "::matches", "difficulty" ], ["value", "::>", "5"], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map { |a| a.last }).to eq([@lion_difficulty.id, @stables_difficulty.id])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])
    end

    it 'ignores ::> for non-numeric strings' do
      query(
        [ 'characteristic', [ "name", "::matches", "stance" ], ["value", "::>", "5"], '::all', '::identifier' ]
      )

      expect(json_body[:answer]).to eq([])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])
    end

    it 'supports ::>= for numeric strings' do
      query(
        [ 'characteristic', [ "name", "::matches", "difficulty" ], ["value", "::>=", "5.1"], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map { |a| a.last }).to eq([@lion_difficulty.id, @stables_difficulty.id])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])
    end

    it 'ignores ::>= for non-numeric strings' do
      query(
        [ 'characteristic', [ "name", "::matches", "stance" ], ["value", "::>=", "5"], '::all', '::identifier' ]
      )

      expect(json_body[:answer]).to eq([])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])
    end

    it 'supports ::< for numeric strings' do
      query(
        [ 'characteristic', [ "name", "::matches", "difficulty" ], ["value", "::<", "5.1"], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map { |a| a.last }).to eq([@hydra_difficulty.id])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])

      query(
        [ 'characteristic', [ "name", "::matches", "difficulty" ], ["value", "::<", "5.2"], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map { |a| a.last }).to eq([@hydra_difficulty.id, @stables_difficulty.id])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])
    end

    it 'ignores ::< for non-numeric strings' do
      query(
        [ 'characteristic', [ "name", "::matches", "stance" ], ["value", "::<", "5"], '::all', '::identifier' ]
      )

      expect(json_body[:answer]).to eq([])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])
    end

    it 'supports ::<= for numeric strings' do
      query(
        [ 'characteristic', [ "name", "::matches", "difficulty" ], ["value", "::<=", "5.1"], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map { |a| a.last }).to eq([@hydra_difficulty.id, @stables_difficulty.id])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])
    end

    it 'ignores ::<= for non-numeric strings' do
      query(
        [ 'characteristic', [ "name", "::matches", "stance" ], ["value", "::<=", "5"], '::all', '::identifier' ]
      )

      expect(json_body[:answer]).to eq([])
      expect(json_body[:format]).to eq(['labors::characteristic#id', 'labors::characteristic#id'])
    end
  end

  context Magma::NumberPredicate do
    before(:each) do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true, project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false, project: @project)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false, project: @project)

      hide = create(:prize, labor: lion, name: 'hide', worth: 6)
      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)
    end

    it 'supports comparisons' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::!=', 0 ], '::any' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'supports ::in' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::in', [ 5, 6 ] ], '::any' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].map(&:last)).to eq(['Lernean Hydra', 'Nemean Lion'])
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'supports ::not' do
      query(
        [ 'labor', [ 'prize', [ 'worth', '::not', [ 5, 6 ] ], '::any' ], '::all', '::identifier' ]
      )

      expect(json_body[:answer].first.last).to eq('Augean Stables')
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end
  end

  context Magma::DateTimePredicate do
    before(:each) do
      lion = create(:labor, name: 'Nemean Lion', number: 1, year: '02-01-0001', completed: true, project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, year: '03-15-0002', completed: false, project: @project)
      stables = create(:labor, name: 'Augean Stables', number: 5, year: '06-07-0005', completed: false, project: @project)
    end

    it 'supports comparisons' do
      query(
        [ 'labor', [ 'year', '::>', '03-01-0001' ], '::all', '::identifier' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([ 'Augean Stables', 'Lernean Hydra' ])
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'returns in ISO8601 format' do
      query(
        [ 'labor', '::all', 'year' ]
      )

      expect(json_body[:answer].map(&:last)).to match_array(Labors::Labor.select_map(:year).map(&:iso8601))
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#year'])
    end
  end

  context Magma::FilePredicate do
    before(:each) do
      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, name: 'Nemean Lion', stats: '{"filename": "lion-stats.tsv", "original_filename": "alpha-lion.tsv"}', labor: labor)

      labor = create(:labor, :hydra, project: @project)
      hydra = create(:monster, name: 'Lernean Hydra', stats: '{"filename": "hydra-stats.tsv", "original_filename": "alpha-hydra.tsv"}', labor: labor)

      labor = create(:labor, :stables, project: @project)
      stables = create(:monster, name: 'Augean Stables', stats: '{"filename": "stables-stats.tsv", "original_filename": "alpha-stables.tsv"}', labor: labor)
    end

    it 'returns a path' do
      query(
        [ 'monster', '::all', 'stats', '::path' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([ 'hydra-stats.tsv', 'lion-stats.tsv', 'stables-stats.tsv' ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#stats'])
    end

    it 'returns a url' do
      query(
        [ 'monster', '::all', 'stats', '::url' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last)).to all(match(/^https/))
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#stats'])
    end

    it 'returns the original filename' do
      query(
        [ 'monster', '::all', 'stats', '::original_filename' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([ 'alpha-hydra.tsv', 'alpha-lion.tsv', 'alpha-stables.tsv' ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#stats'])
    end

    it 'can filter on ::lacks' do
      practice = create(:labor, name: 'Practice', project: @project)
      paper_tiger = create(:monster, name: 'Roar!', stats: nil, labor: practice)
      paper_dragon = create(:monster, name: 'Whoosh!', stats: 'null', labor: practice)
    
      query(
        [ 'monster', ['::lacks', 'stats'], '::all', '::identifier' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([ 'Roar!', 'Whoosh!' ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#name'])
    end

    it 'can match on filename with ::equals' do
      practice = create(:labor, name: 'Practice', project: @project)
      paper_tiger = create(:monster, name: 'Roar!', stats: '{"filename": "::blank", "original_filename": "::blank"}', labor: practice)
    
      query(
        [ 'monster', ['stats', '::equals', '::blank'], '::all', '::identifier' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([ 'Roar!' ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#name'])
    end

    it 'can match on not filename with ::not' do
      practice = create(:labor, name: 'Practice', project: @project)
      paper_tiger = create(:monster, name: 'Roar!', stats: '{"filename": "::blank", "original_filename": "::blank"}', labor: practice)
    
      query(
        [ 'monster', ['stats', '::not', '::blank'], '::all', '::identifier' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([ 'Augean Stables', 'Lernean Hydra', 'Nemean Lion' ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#name'])
    end

    it 'returns the md5' do
      route_payload = JSON.generate({
        files: Labors::Monster.all.map do |monster|
          {
            file_name: monster.stats["filename"],
            project_name: "labors",
            bucket_name: "magma",
            file_hash: "hashfor#{monster.stats["filename"]}"
          }
        end,
        folders: []
      })

      stub_request(:post, %r!https://metis.test/labors/find/magma!).
        to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})

      query(
        [ 'monster', '::all', 'stats', '::md5' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([
        'hashforhydra-stats.tsv', 'hashforlion-stats.tsv', 'hashforstables-stats.tsv'
      ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#stats'])
    end

    it 'returns the updated_at' do
      route_payload = JSON.generate({
        files: Labors::Monster.all.map do |monster|
          {
            file_name: monster.stats["filename"],
            project_name: "labors",
            bucket_name: "magma",
            updated_at: "updatedatfor#{monster.stats["filename"]}"
          }
        end,
        folders: []
      })

      stub_request(:post, %r!https://metis.test/labors/find/magma!).
        to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})

      query(
        [ 'monster', '::all', 'stats', '::updated_at' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([
        'updatedatforhydra-stats.tsv', 'updatedatforlion-stats.tsv', 'updatedatforstables-stats.tsv'
      ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#stats'])
    end

    it 'returns all the file data' do
      query(
        [ 'monster', '::all', 'stats', '::all' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort_by { |hsh| hsh[:filename] }).
        to eq([
          {original_filename: "alpha-hydra.tsv", filename: "hydra-stats.tsv"},
          {original_filename: "alpha-lion.tsv", filename: "lion-stats.tsv"},
          {original_filename: "alpha-stables.tsv", filename: "stables-stats.tsv"}])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#stats'])
    end
  end

  context Magma::FileCollectionPredicate do
    before(:each) do
      @lion_certs = [{
        filename: 'monster-Nemean Lion-certificates-0.txt',
        original_filename: 'sb_diploma_lion.txt'
      }, {
        filename: 'monster-Nemean Lion-certificates-1.txt',
        original_filename: 'sm_diploma_lion.txt'
      }]
      @hydra_certs = [{
        filename: 'monster-Lernean Hydra-certificates-0.txt',
        original_filename: 'ba_diploma_hydra.txt'
      }, {
        filename: 'monster-Lernean Hydra-certificates-1.txt',
        original_filename: 'phd_diploma_hydra.txt'
      }]
      @stable_certs = [{
        filename: 'monster-Augean Stables-certificates-0.txt',
        original_filename: 'aa_diploma_stables.txt'
      }, {
        filename: 'monster-Augean Stables-certificates-1.txt',
        original_filename: 'jd_diploma_stables.txt'
      }]

      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, name: 'Nemean Lion', certificates: @lion_certs.to_json, labor: labor)

      labor = create(:labor, :hydra, project: @project)
      hydra = create(:monster, name: 'Lernean Hydra', certificates: @hydra_certs.to_json, labor: labor)

      labor = create(:labor, :stables, project: @project)
      stables = create(:monster, name: 'Augean Stables', certificates: @stable_certs.to_json, labor: labor)
    end

    it 'returns paths' do
      query(
        [ 'monster', '::all', 'certificates', '::path' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([
        ["monster-Augean Stables-certificates-0.txt", "monster-Augean Stables-certificates-1.txt"],
        ["monster-Lernean Hydra-certificates-0.txt", "monster-Lernean Hydra-certificates-1.txt"],
        ["monster-Nemean Lion-certificates-0.txt", "monster-Nemean Lion-certificates-1.txt"]
      ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#certificates'])
    end

    it 'returns a url' do
      query(
        [ 'monster', '::all', 'certificates', '::url' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).flatten).to all(match(/^https/))
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#certificates'])
    end

    it 'returns the original filename' do
      query(
        [ 'monster', '::all', 'certificates', '::original_filename' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([
        ["aa_diploma_stables.txt", "jd_diploma_stables.txt"],
        ["ba_diploma_hydra.txt", "phd_diploma_hydra.txt"],
        ["sb_diploma_lion.txt", "sm_diploma_lion.txt"]
      ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#certificates'])
    end

    it 'returns md5s' do
      route_payload = JSON.generate({
        files: Labors::Monster.all.map do |monster|
          monster.certificates.map do |f|
            {
              file_name: f["filename"],
              project_name: "labors",
              bucket_name: "magma",
              file_hash: "hashfor#{f["filename"]}"
            }
          end
        end.flatten,
        folders: []
      })

      stub_request(:post, %r!https://metis.test/labors/find/magma!).
        to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})


      query(
        [ 'monster', '::all', 'certificates', '::md5' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([
        ["hashformonster-Augean Stables-certificates-0.txt", "hashformonster-Augean Stables-certificates-1.txt"],
        ["hashformonster-Lernean Hydra-certificates-0.txt", "hashformonster-Lernean Hydra-certificates-1.txt"],
        ["hashformonster-Nemean Lion-certificates-0.txt", "hashformonster-Nemean Lion-certificates-1.txt"]
      ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#certificates'])
    end

    it 'returns file updated_at' do
      route_payload = JSON.generate({
        files: Labors::Monster.all.map do |monster|
          monster.certificates.map do |f|
            {
              file_name: f["filename"],
              project_name: "labors",
              bucket_name: "magma",
              updated_at: "updatedatfor#{f["filename"]}"
            }
          end
        end.flatten,
        folders: []
      })

      stub_request(:post, %r!https://metis.test/labors/find/magma!).
        to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})


      query(
        [ 'monster', '::all', 'certificates', '::updated_at' ]
      )

      expect(last_response.status).to eq(200)

      expect(json_body[:answer].map(&:last).sort).to eq([
        ["updatedatformonster-Augean Stables-certificates-0.txt", "updatedatformonster-Augean Stables-certificates-1.txt"],
        ["updatedatformonster-Lernean Hydra-certificates-0.txt", "updatedatformonster-Lernean Hydra-certificates-1.txt"],
        ["updatedatformonster-Nemean Lion-certificates-0.txt", "updatedatformonster-Nemean Lion-certificates-1.txt"]
      ])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#certificates'])
    end

    it 'returns all the file data' do
      query(
        [ 'monster', '::all', 'certificates', '::all' ]
      )

      expect(last_response.status).to eq(200)

      sorted_answer = json_body[:answer].map(&:last).sort_by { |arry| arry.first[:filename] }
      expect(sorted_answer.length).to eq(3)
      expect(sorted_answer.flatten.map {|a| a[:url] }).to all(match(/^https/))
      expect(sorted_answer.map {|a| a.each { |hsh| hsh.delete(:url) } }).to eq([
        @stable_certs,
        @hydra_certs,
        @lion_certs])
      expect(json_body[:format]).to eq(['labors::monster#name', 'labors::monster#certificates'])
    end
  end

  context Magma::BooleanPredicate do
    it 'checks ::true' do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true, project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: nil, project: @project)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false, project: @project)
      query([ 'labor', [ 'completed', '::true' ], '::all', 'name' ])
      expect(json_body[:answer].map(&:last)).to eq([ 'Nemean Lion' ])
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'checks ::false' do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true, project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: nil, project: @project)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false, project: @project)
      query([ 'labor', [ 'completed', '::false' ], '::all', 'name' ])
      expect(json_body[:answer].map(&:last)).to eq([ 'Augean Stables' ])
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end

    it 'checks ::untrue' do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true, project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: nil, project: @project)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false, project: @project)
      query([ 'labor', [ 'completed', '::untrue' ], '::all', 'name' ])
      expect(json_body[:answer].map(&:last)).to match_array([ 'Lernean Hydra', 'Augean Stables' ])
      expect(json_body[:format]).to eq(['labors::labor#name', 'labors::labor#name'])
    end
  end

  context Magma::MatrixPredicate do
    before(:each) do
      @attribute = Labors::Labor.attributes[:contributions]
      @attribute.reset_cache
    end

    it 'returns a table of values' do
      matrix = [
        [ 10, 10, 10, 10 ],
        [ 20, 20, 20, 20 ],
        [ 30, 30, 30, 30 ]
      ]
      stables = create(:labor, name: 'Augean Stables', number: 5, contributions: matrix[0], project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, contributions: matrix[1], project: @project)
      lion = create(:labor, name: 'Nemean Lion', number: 1, contributions: matrix[2], project: @project)

      query(
        [ 'labor',
          '::all',
          'contributions'
        ]
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map(&:last)).to eq(matrix)
      expect(json_body[:format]).to eq(["labors::labor#name", ["labors::labor#contributions", ["Athens", "Sparta", "Sidon", "Thebes"]]])
    end

    it 'returns a slice of the data' do
      matrix = [
        [ 10, 11, 12, 13 ],
        [ 20, 21, 22, 23 ],
        [ 30, 31, 32, 33 ]
      ]
      stables = create(:labor, name: 'Augean Stables', number: 5, contributions: matrix[0], project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, contributions: matrix[1], project: @project)
      lion = create(:labor, name: 'Nemean Lion', number: 1, contributions: matrix[2], project: @project)

      query(
        [ 'labor',
          '::all',
          'contributions',
          '::slice',
          [ 'Athens', 'Sparta' ]
        ]
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map(&:last)).to eq(matrix.map{|r| r[0..1]})
      expect(json_body[:format]).to eq(["labors::labor#name", ["labors::labor#contributions", ["Athens", "Sparta" ]]])
    end

    it 'complains about invalid slices' do
      matrix = [
        [ 10, 11, 12, 13 ],
        [ 20, 21, 22, 23 ],
        [ 30, 31, 32, 33 ]
      ]
      stables = create(:labor, name: 'Augean Stables', number: 5, contributions: matrix[0])
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, contributions: matrix[1])
      lion = create(:labor, name: 'Nemean Lion', number: 1, contributions: matrix[2])

      query(
        [ 'labor',
          '::all',
          'contributions',
          '::slice',
          [ 'Bathens', 'Sporta' ]
        ]
      )

      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(['Invalid verb arguments ::slice, Bathens, Sporta'])
    end

    it 'returns nil values for empty rows' do
      stables = create(:labor, name: 'Augean Stables', number: 5, project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, project: @project)
      lion = create(:labor, name: 'Nemean Lion', number: 1, project: @project)

      query(
        [ 'labor',
          '::all',
          'contributions'
        ]
      )
      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map(&:last)).to eq(
        [ [ nil ] * @attribute.validation_object.options.length ] * 3
      )

      query(
        [ 'labor',
          '::all',
          'contributions',
          '::slice',
          [ 'Athens', 'Thebes' ]
        ]
      )
      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map(&:last)).to eq(
        [ [ nil, nil ] ] * 3
      )
      expect(json_body[:format]).to eq(["labors::labor#name", ["labors::labor#contributions", ["Athens", "Thebes"]]])
    end

    it 'returns updated values' do
      matrix = [
        [ 10, 10, 10, 10 ],
        [ 20, 20, 20, 20 ],
        [ 30, 30, 30, 30 ]
      ]
      stables = create(:labor, name: 'Augean Stables', number: 5, contributions: matrix[0], project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, contributions: matrix[1], project: @project)
      lion = create(:labor, name: 'Nemean Lion', number: 1, contributions: matrix[2], project: @project)

      query(
        [ 'labor',
          '::all',
          'contributions'
        ]
      )
      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map(&:last)).to eq(matrix)

      # make an update
      update(
        'labor' => {
          'Nemean Lion' => {
            contributions: matrix[1]
          }
        }
      )
      expect(last_response.status).to eq(200)
      lion.refresh
      expect(lion.contributions).to eq(matrix[1])

      # the new query should reflect the updated values
      query(
        [ 'labor',
          '::all',
          'contributions'
        ]
      )
      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map(&:last)).to eq(matrix.values_at(0,1,1))
      expect(json_body[:format]).to eq(["labors::labor#name", ["labors::labor#contributions", ["Athens", "Sparta", "Sidon", "Thebes"]]])
    end
  end

  context Magma::MatchPredicate do
    before(:each) do
      @entry = create(:codex,
        monster: 'Nemean Lion',
        aspect: 'hide',
        tome: 'Bullfinch',
        lore: {
          type: 'String',
          value: 'fur'
        },
        project: @project
      )
    end

    it 'returns a match' do
      query( [ 'codex', '::first', 'lore' ])
      expect(last_response.status).to eq(200)
      expect(json_body[:answer]).to eq(type: 'String', value: 'fur')
    end

    it 'returns a match type' do
      query( [ 'codex', '::first', 'lore', '::type' ])
      expect(last_response.status).to eq(200)
      expect(json_body[:answer]).to eq('String')
    end

    it 'returns a match value' do
      query( [ 'codex', '::first', 'lore', '::value' ])
      expect(last_response.status).to eq(200)
      expect(json_body[:answer]).to eq('fur')
    end
  end

  context Magma::TablePredicate do
    before(:each) do
      Labors::Labor.attributes[:contributions].reset_cache
    end

    it 'can return an arrayed result' do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true, contributions: [ 10, 10, 10, 10 ], project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false, project: @project)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false, project: @project)

      poison = create(:prize, labor: hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: stables, name: 'poop', worth: 0)

      query(
        [ 'labor', '::all',

          # The table argument
          [
            [ 'number' ],
            [ 'completed' ],
            [ 'contributions', '::slice', [ 'Thebes' ] ],

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
        ['Augean Stables', [5, false, [ nil ], nil, 0, nil]],
        ['Lernean Hydra', [2, false, [ nil ], 5, nil, nil]],
        ['Nemean Lion', [1, true, [ 10 ], nil, nil, nil]]
      ])

      expect(json_body[:format]).to eq([
        'labors::labor#name',
        [
          'labors::labor#number',
          'labors::labor#completed',
          [ 'labors::labor#contributions', [ 'Thebes' ] ],
          'labors::prize#worth',
          'labors::prize#worth',
          'labors::prize#worth'
        ]
      ])
    end
  end

  context 'pagination' do
    it 'can order by an additional parameter across pages' do
      labor_list = []
      labor_list << create(:labor, name: "d", project: @project)
      labor_list << create(:labor, name: "a", project: @project)
      labor_list << create(:labor, name: "c", project: @project)
      labor_list << create(:labor, name: "b", project: @project)

      query_opts(
        [ 'labor', '::all', '::identifier'],
        order: 'updated_at',
        page: 1,
        page_size: 2
      )

      expect(json_body[:answer].map {|a| a.first }).to eq(["d", "a"])
    end

    it 'can order results for a total query' do
      labor_list = []
      labor_list << create(:labor, name: "a", updated_at: Time.now + 5, project: @project)
      labor_list << create(:labor, name: "c", updated_at: Time.now - 3, project: @project)
      labor_list << create(:labor, name: "b", updated_at: Time.now - 2, project: @project)

      labor_list_by_identifier = labor_list.sort_by { |n| n.name.to_s }

      query(
        [ 'labor', '::all', 'name']
      )

      names_by_identifier = labor_list_by_identifier.map(&:name)
      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map { |a| a.last }).to eq(names_by_identifier)

      labor_list_by_updated_at = labor_list.sort_by(&:updated_at)
      query_opts(
        [ 'labor', '::all', 'name'],
        order: 'updated_at'
      )

      names_by_updated_at = labor_list_by_updated_at.map(&:name)
      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map { |a| a.last }).to eq(names_by_updated_at)

      expect(names_by_updated_at).to_not eql(names_by_identifier)
    end

    it 'can page results' do
      labor_list = create_list(:labor, 9, project: @project)
      third_page_labors = labor_list.sort_by(&:name)[6..8]

      query_opts(
        [ 'labor', '::all', 'name'],
        page: 3,
        page_size: 3
      )

      names = third_page_labors.map(&:name)
      
      expect(last_response.status).to eq(200)
      expect(json_body[:answer].map { |a| a.last }).to eq(names)
    end

    it 'can page results with joined collections' do
      labor = create(:labor, :lion, project: @project)
      monster_list = create_list(:monster, 9, labor: labor)
      victim_list = monster_list.map do |monster|
        create_list(:victim, 2, monster: monster)
      end.flatten

      names = monster_list.sort_by(&:name)[6..8].map(&:name)

      query_opts(
        [ 'monster', '::all', 'name'],
        order: 'reference_monster',
        page: 3,
        page_size: 3
      )

      expect(json_body[:answer].map { |a| a.last }).to eq(names)
    end

    it 'returns a descriptive error when no results are retrieved on paginated query' do
      lion = create(:labor, :lion)
      hydra = create(:labor, :hydra)
      stables = create(:labor, :stables)

      query_opts(
        [ 'labor', '::all', 'name'],
        page: 3,
        page_size: 3
      )

      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Page 3 not found"])
    end

    it 'can paginate with one-to-many relationships' do 
      lion = create(:labor, project: @project, name: 'Nemean Lion')
      hydra = create(:labor, project: @project, name: 'Lernean Hydra')
      stables = create(:labor, project: @project, name: 'Augean Stables')
      poison = create(:prize, labor: hydra, name: 'poison', worth: 0)
      poop = create(:prize, labor: stables, name: 'poop', worth: 4)
      iou = create(:prize, labor: stables, name: 'iou', worth: 3)
      skin = create(:prize, labor: lion, name: 'skin', worth: 5)

      query_opts(
        ['labor', ['prize', [ '::has', 'worth' ], '::any'], '::all', 'name' ],
        page: 1,
        page_size: 2
      )
      
      expect(json_body[:answer].map { |a| a.last }).to eq(
        ['Augean Stables', 'Lernean Hydra'])
    end

    it 'can paginate and order with one-to-many relationships' do 
      now = DateTime.now
      
      Timecop.freeze(now - 1000)

      lion = create(:labor, project: @project, name: 'Nemean Lion')
      
      Timecop.freeze(now - 500)
      
      hydra = create(:labor, project: @project, name: 'Lernean Hydra')
      
      Timecop.freeze(now - 250)
      
      stables = create(:labor, project: @project, name: 'Augean Stables')

      Timecop.return

      poison = create(:prize, labor: hydra, name: 'poison', worth: 0)
      poop = create(:prize, labor: stables, name: 'poop', worth: 4)
      iou = create(:prize, labor: stables, name: 'iou', worth: 3)
      skin = create(:prize, labor: lion, name: 'skin', worth: 5)

      query_opts(
        ['labor', ['prize', [ '::has', 'worth' ], '::any'], '::all', 'name' ],
        page: 1,
        page_size: 2,
        order: 'updated_at'
      )

      expect(json_body[:answer].map { |a| a.last }).to eq(
        ['Nemean Lion', 'Lernean Hydra'])
    end
  end

  context 'restriction' do
    before(:each) do
      labor = create(:labor, :lion, project: @project)
      @lion = create(:monster, :lion, labor: labor)
    end

    it 'hides restricted records' do
      restricted_victim_list = create_list(:victim, 9, restricted: true, monster: @lion)
      unrestricted_victim_list = create_list(:victim, 9, monster: @lion)

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
      restricted_victim_list = create_list(:victim, 9, restricted: true, monster: @lion)
      unrestricted_victim_list = create_list(:victim, 9, monster: @lion)

      query(
        [ 'victim', '::all',
          [
            [ '::identifier' ]
          ]
        ],
        :privileged_editor
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
      victim_list = create_list(:victim, 9, country: 'thrace', monster: @lion)

      query([ 'victim', '::all', 'country' ])
      expect(last_response.status).to eq(403)
    end

    it 'allows queries on restricted attributes to users with restricted permission' do
      victim_list = create_list(:victim, 9, country: 'thrace')

      query([ 'victim', '::all', 'country' ], :privileged_editor)
      expect(json_body[:answer].map(&:last).sort).to all(eq('thrace'))
    end
  end
end
