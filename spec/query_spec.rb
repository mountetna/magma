describe QueryController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    route_payload = JSON.generate([
      {:success=>true}
    ])
    stub_request(:any, /https:\/\/metis.test/).
      to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})
    @project = create(:project, name: 'The Twelve Labors of Hercules')
  end

  def query(question,user_type=:viewer)
    auth_header(user_type)
    json_post(:query, {project_name: 'labors', query: question})
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
    before(:each) do
      @hydra = create(:labor, :hydra, project: @project)
      @stables = create(:labor, :stables, project: @project)
      @lion = create(:labor, :lion, project: @project)
      @hind = create(:labor, :hind, project: @project)
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

    it 'supports ::any' do
      poison = create(:prize, name: 'poison', worth: 5, labor: @hydra)
      poop = create(:prize, name: 'poop', worth: 0, labor: @stables)

      query(['prize', [ 'worth', '::>', 0 ], '::any' ])

      expect(json_body[:answer]).to eq(true)
      expect(json_body[:format]).to eq('Boolean')
    end

    it 'supports ::count' do
      poison = create(:prize, labor: @hydra, name: 'poison', worth: 5)
      poop = create(:prize, labor: @stables, name: 'poop', worth: 0)
      iou = create(:prize, labor: @stables, name: 'iou', worth: 2)
      skin = create(:prize, labor: @lion, name: 'skin', worth: 6)

      query(['labor', '::all', 'prize', '::count' ])

      expect(json_body[:answer]).to eq([
        [ 'Augean Stables', 2 ],
        #[ 'Ceryneian Hind', 0 ],
        [ 'Lernean Hydra', 1 ],
        [ 'Nemean Lion', 1 ]
      ])
      expect(json_body[:format]).to eq(['labors::labor#name', 'Numeric'])
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
      poison = create(:prize, labor: @hydra, name: 'poison', worth: 5, labor: @hydra)
      poop = create(:prize, labor: @stables, name: 'poop', worth: 0, labor: @stables)
      query(['labor', '::all', '::metrics'])

      answer = Hash[json_body[:answer]]
      expect(answer['Lernean Hydra'][:lucrative][:score]).to eq('success')
    end
  end

  context Magma::StringPredicate do
    before(:each) do
      lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true, project: @project)
      hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false, project: @project)
      stables = create(:labor, name: 'Augean Stables', number: 5, completed: false, project: @project)
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
      lion = create(:monster, name: 'Nemean Lion', certificates: @lion_certs.to_json)
      hydra = create(:monster, name: 'Lernean Hydra', certificates: @hydra_certs.to_json)
      stables = create(:monster, name: 'Augean Stables', certificates: @stable_certs.to_json)
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
