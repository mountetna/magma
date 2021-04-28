describe RetrieveController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  def retrieve(post, user_type=:viewer)
    auth_header(user_type)
    json_post(:retrieve, post)
  end

  before(:each) do
    @project = create(:project, name: 'The Twelve Labors of Hercules')
  end

  it 'fails for non-users' do
    retrieve(
      {
        model_name: 'labor',
        record_names: [],
        attribute_names: [],
        project_name: 'labors'
      },
      :non_user
    )
    expect(last_response.status).to eq(403)
  end

  it 'calls the retrieve endpoint and returns a template.' do
    retrieve(
      model_name: 'aspect',
      record_names: [],
      attribute_names: [],
      project_name: 'labors'
    )
    expect(last_response.status).to eq(200)

    json_template = json_body[:models][:aspect][:template]

    # all attributes are present
    expect(json_template[:attributes].keys).to eq(
      Labors::Aspect.attributes.keys
    )

    # attributes are well-formed
    expect(json_template[:attributes].map{|att_name,att| att.keys.sort}).to all(include( :attribute_type, :display_name, :name, :hidden))

    # the identifier is reported
    expect(json_template[:identifier]).to eq('id')

    # the name is reported
    expect(json_template[:name]).to eq('aspect')

    # the parent model is reported
    expect(json_template[:parent]).to eq('monster')

    # the dictionary model is reported
    expect(json_template[:dictionary]).to eq(
      dictionary_model: "Labors::Codex",
      project_name: 'labors',
      model_name: 'codex',
      attributes: {monster: 'monster', name: 'aspect', source: 'tome', value: 'lore'}
    )
  end

  it 'optionally does not return a template' do
    retrieve(
      model_name: 'project',
      record_names: 'all',
      attribute_names: 'all',
      project_name: 'labors',
      hide_templates: true
    )
    expect(last_response.status).to eq(200)

    expect(json_body[:models][:project][:documents].size).to eq(1)
    expect(json_body[:models][:project][:template]).to be_nil
  end

  it 'complains with missing params.' do
    retrieve(project_name: 'labors')
    expect(last_response.status).to eq(422)
  end

  it 'can get all models from the retrieve endpoint.' do
    retrieve(
      project_name: 'labors',
      model_name: 'all',
      record_names: [],
      attribute_names: 'all'
    )
    expect(last_response).to(be_ok)
  end

  it 'complains if there are record names for all models' do
    retrieve(
      project_name: 'labors',
      model_name: 'all',
      record_names: [ 'record1', 'record2' ],
      attribute_names: []
    )

    expect(last_response.status).to eq(422)
  end

  it 'forbids grabbing the entire dataset' do
    retrieve(
      project_name: 'labors',
      model_name: 'all',
      record_names: 'all',
      attribute_names: 'all'
    )
    expect(last_response.status).to eq(422)
  end

  context 'files' do
    it 'retrieves file attributes with storage links' do
      Timecop.freeze(DateTime.new(500))
      labor = create(:labor, :lion, project: @project)
      monster = create(:monster, :lion, stats: '{"filename": "stats.txt", "original_filename": ""}', labor: labor)

      retrieve(
        project_name: 'labors',
        model_name: 'monster',
        record_names: [ 'Nemean Lion' ],
        attribute_names: [ 'stats' ]
      )

      expect(last_response.status).to eq(200)
      uri = URI.parse(json_document(:monster, 'Nemean Lion')[:stats][:url])
      params = Rack::Utils.parse_nested_query(uri.query)

      expect(uri.host).to eq(Magma.instance.config(:storage)[:host])
      expect(uri.path).to eq('/labors/download/magma/stats.txt')
      expect(params['X-Etna-Id']).to eq('magma')
      expect(params['X-Etna-Expiration']).to eq((Time.now + Magma.instance.config(:storage)[:download_expiration]).iso8601)

      Timecop.return
    end
  end

  context 'file collection' do
    it 'retrieves file attributes with storage links' do
      Timecop.freeze(DateTime.new(500))

      lion_certs = [{
        filename: 'monster-Nemean Lion-certificates-0.txt',
        original_filename: 'sb_diploma_lion.txt'
      }, {
        filename: 'monster-Nemean Lion-certificates-1.txt',
        original_filename: 'sm_diploma_lion.txt'
      }]

      labor = create(:labor, :lion, project: @project)
      monster = create(
        :monster,
        :lion,
        labor: labor,
        certificates: lion_certs.to_json)

      retrieve(
        project_name: 'labors',
        model_name: 'monster',
        record_names: [ 'Nemean Lion' ],
        attribute_names: [ 'certificates' ]
      )

      expect(last_response.status).to eq(200)
      uris = []
      uris << URI.parse(json_document(:monster, 'Nemean Lion')[:certificates].first[:url])
      uris << URI.parse(json_document(:monster, 'Nemean Lion')[:certificates].last[:url])
      params = uris.map { |u| Rack::Utils.parse_nested_query(u.query) }

      expect(uris.all? { |u| u.host == Magma.instance.config(:storage)[:host] }).to eq(true)
      expect(uris.first.path).to eq('/labors/download/magma/monster-Nemean%20Lion-certificates-0.txt')
      expect(uris.last.path).to eq('/labors/download/magma/monster-Nemean%20Lion-certificates-1.txt')
      expect(params.all? { |p| p['X-Etna-Id'] == 'magma' }).to eq(true)
      expect(params.all? { |p|
        p['X-Etna-Expiration'] == (Time.now + Magma.instance.config(:storage)[:download_expiration]).iso8601 }).to eq(true)

      Timecop.return
    end
  end

  context 'disconnected data' do
    it 'does not retrieve disconnected records' do
      labors = create_list(:labor,3, project: @project)
      disconnected_labors = create_list(:labor,3)

      retrieve(
        project_name: 'labors',
        model_name: 'all',
        record_names: 'all',
        attribute_names: 'identifier'
      )

      expect(last_response.status).to eq(200)

      # only attached models are returned
      expect(json_body[:models][:labor][:documents].keys).to match_array(labors.map(&:name).map(&:to_sym))
    end

    it 'retrieves disconnected records if asked' do
      labors = create_list(:labor,3, project: @project)
      disconnected_labors = create_list(:labor,3)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'identifier',
        show_disconnected: true
      )

      expect(last_response.status).to eq(200)

      # only attached models are returned
      expect(json_body[:models][:labor][:documents].keys).to match_array((disconnected_labors).map(&:name).map(&:to_sym))
    end
  end

  context 'identifiers' do
    it 'allows grabbing the entire set of identifiers' do
      labors = create_list(:labor,3, project: @project)
      monsters = create_list(:monster,3, labor: labors.first)
      prizes = create_list(:prize,3, labor: labors.last)
      retrieve(
        project_name: 'labors',
        model_name: 'all',
        record_names: 'all',
        attribute_names: 'identifier'
      )
      expect(last_response.status).to eq(200)
      json = json_body

      # any model with an identifier returns all records
      expect(json[:models][:labor][:documents].keys).to match_array(labors.map(&:name).map(&:to_sym))
      expect(json[:models][:monster][:documents].keys).to match_array(monsters.map(&:name).map(&:to_sym))

      # it does not return a model with no identifier
      expect(json[:models][:prize]).to be_nil
    end

    it 'retrieves records by identifier' do
      labors = create_list(:labor,3, project: @project)

      names = labors.map(&:name).map(&:to_sym)

      retrieve(
        model_name: 'labor',
        record_names: names[0..1],
        attribute_names: 'all',
        project_name: 'labors'
      )

      json = json_body

      expect(json[:models][:labor][:documents]).to have_key(names.first)
      expect(json[:models][:labor][:documents]).not_to have_key(names.last)
    end

    it 'can retrieve records by id if there is no identifier' do
      labor = create(:labor, :lion, project: @project)
      prizes = create_list(:prize,3, labor: labor)
      retrieve(
        project_name: 'labors',
        model_name: 'prize',
        record_names: prizes[0..1].map(&:id),
        attribute_names: 'all'
      )

      expect(json_body[:models][:prize][:documents].keys).to eq(prizes[0..1].map(&:id).map(&:to_s).map(&:to_sym))
    end
  end

  context 'collections' do
    it 'retrieves collections as a list of identifiers' do
      labors = create_list(:labor, 3, project: @project)

      retrieve(
        model_name: 'project',
        record_names: [ @project.name ],
        attribute_names: [ 'labor' ],
        project_name: 'labors'
      )

      project_doc = json_body[:models][:project][:documents][@project.name.to_sym]

      expect(project_doc).not_to be_nil
      expect(project_doc[:labor]).to match_array(labors.map(&:name))
    end

    it 'returns an empty list for empty collections' do
      retrieve(
        model_name: 'project',
        record_names: [ @project.name ],
        attribute_names: [ 'labor' ],
        project_name: 'labors'
      )

      project_doc = json_body[:models][:project][:documents][@project.name.to_sym]

      expect(project_doc).not_to be_nil
      expect(project_doc[:labor]).to eq([])
    end
  end

  context 'tables' do
    it 'retrieves table associations' do
      lion = create(:labor, :lion, project: @project)
      hydra = create(:labor, :hydra, project: @project)
      stables = create(:labor, :stables, project: @project)
      lion_prizes = create_list(:prize, 3, labor: lion)
      hydra_prizes = create_list(:prize, 3, labor: hydra)
      stables_prizes = create_list(:prize, 3, labor: stables)

      selected_prize_ids = (lion_prizes + hydra_prizes).map do |prize|
        prize.send(Labors::Prize.identity.column_name).to_s
      end.sort

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: [ 'Nemean Lion', 'Lernean Hydra' ],
        attribute_names: [ 'prize' ]
      )

      models = json_body[:models]

      # the labor documents are received with the table identifiers filled in
      expect(models[:labor][:documents].size).to eq(2)
      expect(models[:labor][:documents][:'Nemean Lion'][:prize]).to match_array(lion_prizes.map(&:id))
      expect(models[:labor][:documents][:'Lernean Hydra'][:prize]).to match_array(hydra_prizes.map(&:id))

      # the prize documents are also included
      expect(models[:prize][:documents].keys.sort.map(&:to_s)).to eq(selected_prize_ids)
      expect(models[:prize][:documents].values.first.keys.sort).to eq(
        [:created_at, :id, :labor, :name, :updated_at, :worth ]
      )
    end

    it 'does not retrieve table associations with collapse_tables' do
      lion = create(:labor, :lion, project: @project)
      hydra = create(:labor, :hydra, project: @project)
      stables = create(:labor, :stables, project: @project)
      lion_prizes = create_list(:prize, 3, labor: lion)
      hydra_prizes = create_list(:prize, 3, labor: hydra)
      stables_prizes = create_list(:prize, 3, labor: stables)

      selected_prize_ids = (lion_prizes + hydra_prizes).map do |prize|
        prize.send(Labors::Prize.identity.column_name).to_s
      end.sort

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        collapse_tables: true,
        record_names: [ 'Nemean Lion', 'Lernean Hydra' ],
        attribute_names: [ 'prize' ]
      )

      models = json_body[:models]

      # the labor documents are received without table identifiers filled in
      expect(models[:labor][:documents].size).to eq(2)
      expect(models[:labor][:documents][:'Nemean Lion'][:prize]).to eq(nil)
      expect(models[:labor][:documents][:'Lernean Hydra'][:prize]).to eq(nil)

      # the prize documents are missing
      expect(models[:prize]).to eq(nil)
    end
  end

  context 'tsv format' do
    it 'can retrieve a TSV of data from the endpoint' do
      labor_list = create_list(:labor, 12, project: @project)
      required_atts = ['name', 'completed', 'number']
      retrieve(
        model_name: 'labor',
        record_names: 'all',
        attribute_names: required_atts,
        format: 'tsv',
        project_name: 'labors'
      )
      header, *table = CSV.parse(last_response.body, col_sep: "\t")

      expect(header).to eq(required_atts)
      expect(table).to match_array(labor_list.map{|l| [ l.name, l.completed.to_s, l.number.to_s ] })
    end

    it 'can retrieve the whole TSV' do
      labor_list = create_list(:labor, 200, project: @project)
      required_atts = ['name', 'completed', 'number']
      retrieve(
        model_name: 'labor',
        record_names: 'all',
        attribute_names: required_atts,
        format: 'tsv',
        project_name: 'labors'
      )
      expect(last_response.status).to eq(200)
      expect(last_response.body.count("\n")).to eq(201)
    end

    it 'can retrieve a TSV of data without an identifier' do
      labor = create(:labor, :lion, project: @project)
      prize_list = create_list(:prize, 12, worth: 5, labor: labor)
      retrieve(
        project_name: 'labors',
        model_name: 'prize',
        record_names: 'all',
        attribute_names: 'all',
        format: 'tsv'
      )
      header, *table = CSV.parse(last_response.body, col_sep: "\t")

      expect(table).to match_array(prize_list.map{|l| header.map{|h| h == "labor" ? l.labor.identifier : l.send(h)&.to_s} })
    end

    it 'can retrieve a TSV of collection attribute' do
      labors = create_list(:labor, 3, project: @project)

      retrieve(
        model_name: 'project',
        record_names: [ @project.name ],
        attribute_names: [ 'labor' ],
        project_name: 'labors',
        format: 'tsv'
      )

      header, *table = CSV.parse(last_response.body, col_sep: "\t")
      expect(table).to match_array([ [ "The Twelve Labors of Hercules", labors.map(&:identifier).join(', ') ] ])
    end

    it 'retrieves a TSV with file attributes as urls' do
      Timecop.freeze(DateTime.new(500))
      lion = create(:monster, :lion, stats: '{"filename": "lion.txt", "original_filename": ""}')
      hydra = create(:monster, :hydra, stats: '{"filename": "hydra.txt", "original_filename": ""}')
      hind = create(:monster, :hind, stats: '{"filename": "hind.txt", "original_filename": ""}')

      retrieve(
        project_name: 'labors',
        model_name: 'monster',
        record_names: 'all',
        attribute_names: [ 'stats' ],
        format: 'tsv'
      )

      expect(last_response.status).to eq(200)
      header, *table = CSV.parse(last_response.body, col_sep: "\t")

      uris = table.map{|l| URI.parse(l.last)}
      expect(uris.map(&:host)).to all(eq(Magma.instance.config(:storage)[:host]))
      expect(uris.map(&:path)).to all(match(%r!/labors/download/magma/\w+.txt!))

      Timecop.return
    end

    it 'retrieves a TSV with file collection attributes as urls' do
      Timecop.freeze(DateTime.new(500))
      lion_certs = [{
        filename: 'monster-Nemean Lion-certificates-0.txt',
        original_filename: 'sb_diploma_lion.txt'
      }, {
        filename: 'monster-Nemean Lion-certificates-1.txt',
        original_filename: 'sm_diploma_lion.txt'
      }]
      hydra_certs = [{
        filename: 'monster-Lernean Hydra-certificates-0.txt',
        original_filename: 'ba_diploma_hydra.txt'
      }, {
        filename: 'monster-Lernean Hydra-certificates-1.txt',
        original_filename: 'phd_diploma_hydra.txt'
      }]

      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, :lion, certificates: lion_certs.to_json, labor: labor)

      labor = create(:labor, :hydra, project: @project)
      hydra = create(:monster, :hydra, certificates: hydra_certs.to_json, labor: labor)

      labor = create(:labor, :hind, project: @project)
      hind = create(:monster, :hind, labor: labor)

      retrieve(
        project_name: 'labors',
        model_name: 'monster',
        record_names: 'all',
        attribute_names: [ 'certificates' ],
        format: 'tsv'
      )

      expect(last_response.status).to eq(200)
      header, *table = CSV.parse(last_response.body, col_sep: "\t")

      expect(table.first.last).to eq(nil)
      uris = table.slice(1, 2).map{|l| JSON.parse(l.last).map{|u| URI.parse(u)}}.flatten
      expect(uris.map(&:host)).to all(eq(Magma.instance.config(:storage)[:host]))
      expect(uris.map(&:path)).to all(match(%r!/labors/download/magma/.+.txt!))

      Timecop.return
    end
  end

  context 'filtering' do
    it 'can use a filter' do
      lion = create(:labor, :lion, project: @project)
      hydra = create(:labor, :hydra, project: @project)
      stables = create(:labor, :stables, project: @project)
      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'name~L'
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].count).to eq(2)
    end
    
    it 'can filter on a string list using JSON' do
      lion = create(:labor, :lion, completed: true, project: @project)
      hydra = create(:labor, :hydra, completed: false, project: @project)
      stables = create(:labor, :stables, completed: true, project: @project)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: ['name[]Lernean Hydra,Nemean Lion']
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].count).to eq(2)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: ['name[]Lernean Hydra,Nemean L']
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].count).to eq(1)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: ["project[]none,#{@project.name}"]
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].count).to eq(3)
    end

    it 'can use an "in" filter for a string' do
      lion = create(:labor, :lion, notes: "hard", project: @project)
      hydra = create(:labor, :hydra, notes: "easy", project: @project)
      stables = create(:labor, :stables, notes: "no sweat", project: @project)
      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'notes[]hard,easy'
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].count).to eq(2)
    end

    it 'can use a "lacks" filter for a string' do
      lion = create(:labor, :lion, notes: "hard", project: @project)
      hydra = create(:labor, :hydra, notes: "easy", project: @project)
      stables = create(:labor, :stables, notes: nil, project: @project)
      
      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'notes^@'
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].count).to eq(1)
    end

    it 'can use a "lacks" filter for a foreign key' do
      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, name: 'Nemean Lion', labor: labor)

      labor = create(:labor, :hydra, project: @project)
      hydra = create(:monster, name: 'Lernean Hydra', reference_monster: lion, labor: labor)

      labor = create(:labor, :stables, project: @project)
      stables = create(:monster, name: 'Augean Stables', reference_monster: hydra, labor: labor)
          
      retrieve(
        project_name: 'labors',
        model_name: 'monster',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'reference_monster^@'
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:monster][:documents].count).to eq(1)
    end

    it 'can use a JSON filter' do
      lion = create(:labor, :lion, completed: true, project: @project)
      hydra = create(:labor, :hydra, completed: false, project: @project)
      stables = create(:labor, :stables, completed: true, project: @project)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: ['name~L']
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].count).to eq(2)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: ['name~L', 'completed=true']
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].count).to eq(1)
    end

    it 'can have spaces when using a JSON filter' do
      lion = create(:labor, :lion, completed: true, project: @project)
      hydra = create(:labor, :hydra, completed: false, project: @project)
      stables = create(:labor, :stables, completed: true, project: @project)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: ['name=Lernean Hydra']
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].count).to eq(1)
    end

    it 'can filter numeric strings' do
      lion = create(:labor, :lion, project: @project)
      hydra = create(:labor, :hydra, project: @project)
      stables = create(:labor, :stables, project: @project)

      lion_difficulty = create(:characteristic, labor: lion, name: "difficulty", value: "10" )
      hydra_difficulty = create(:characteristic, labor: hydra, name: "difficulty", value: "2" )
      stables_difficulty = create(:characteristic, labor: stables, name: "difficulty", value: "5" )
    
      lion_stance = create(:characteristic, labor: lion, name: "stance", value: "wrestling" )
      hydra_stance = create(:characteristic, labor: hydra, name: "stance", value: "hacking" )
      stables_stance = create(:characteristic, labor: stables, name: "stance", value: "shoveling" )
    
      retrieve(
        project_name: 'labors',
        model_name: 'characteristic',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'name~difficulty value>5'
      )
      expect(last_response.status).to eq(200)
      expect(json_body[:models][:characteristic][:documents].count).to eq(1)


      retrieve(
        project_name: 'labors',
        model_name: 'characteristic',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'name~stance value>5'
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:characteristic][:documents].count).to eq(0)
    end

    it 'can filter numbers with "lacks"' do
      stables = create(:labor, :stables, project: @project)
      poison = create(:prize, name: 'poison', worth: 5, labor: stables)
      poop = create(:prize, name: 'poop', worth: nil, labor: stables)
      iou = create(:prize, name: 'iou', worth: 2, labor: stables)
      skin = create(:prize, name: 'skin', worth: nil, labor: stables)
      retrieve(
        project_name: 'labors',
        model_name: 'prize',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'worth^@'
      )

      expect(last_response.status).to eq(200)

      prize_names = json_body[:models][:prize][:documents].values.map{|d| d[:name]}
      expect(prize_names).to eq(['poop', 'skin'])
    end

    it 'can filter on numbers' do
      stables = create(:labor, :stables, project: @project)
      poison = create(:prize, name: 'poison', worth: 5, labor: stables)
      poop = create(:prize, name: 'poop', worth: 0, labor: stables)
      iou = create(:prize, name: 'iou', worth: 2, labor: stables)
      skin = create(:prize, name: 'skin', worth: 6, labor: stables)
      retrieve(
        project_name: 'labors',
        model_name: 'prize',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'worth>2'
      )

      expect(last_response.status).to eq(200)

      prize_names = json_body[:models][:prize][:documents].values.map{|d| d[:name]}
      expect(prize_names).to eq(['poison', 'skin'])
    end

    it 'cannot filter on tables' do
      stables = create(:labor, :stables, project: @project)
      poison = create(:prize, name: 'poison', worth: 5, labor: stables)
      poop = create(:prize, name: 'poop', worth: 0, labor: stables)
      iou = create(:prize, name: 'iou', worth: 2, labor: stables)
      skin = create(:prize, name: 'skin', worth: 6, labor: stables)
      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'prize>2'
      )

      expect(last_response.status).to eq(422)
    end

    it 'can filter on dates' do
      old_labors = create_list(:labor, 3, year: DateTime.new(500), project: @project)
      new_labors = create_list(:labor, 3, year: DateTime.new(2000), project: @project)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'year>1999-01-01'
      )

      expect(last_response.status).to eq(200)

      labor_names = json_body[:models][:labor][:documents].values.map{|d| d[:name]}
      expect(labor_names).to match_array(new_labors.map(&:name))
    end

    it 'can filter on dates with "lacks"' do
      old_labors = create_list(:labor, 3, year: DateTime.new(500), project: @project)
      new_labors = create_list(:labor, 3, year: nil, project: @project)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'year^@'
      )

      expect(last_response.status).to eq(200)

      labor_names = json_body[:models][:labor][:documents].values.map{|d| d[:name]}
      expect(labor_names).to match_array(new_labors.map(&:name))
    end

    it 'can filter on updated_at, created_at' do
      Timecop.freeze(DateTime.new(500))
      old_labors = create_list(:labor, 3, project: @project)

      Timecop.freeze(DateTime.new(2000))
      new_labors = create_list(:labor, 3, project: @project)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'updated_at>1999-01-01 created_at>1999-01-01'
      )

      expect(last_response.status).to eq(200)

      labor_names = json_body[:models][:labor][:documents].values.map{|d| d[:name]}
      expect(labor_names).to match_array(new_labors.map(&:name))

      Timecop.return
    end

    it 'can filter files with "lacks"' do
      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, name: 'Nemean Lion', stats: '{"filename": "lion-stats.tsv", "original_filename": "alpha-lion.tsv"}', labor: labor)

      labor = create(:labor, :hydra, project: @project)
      hydra = create(:monster, name: 'Lernean Hydra', stats: nil, labor: labor)

      labor = create(:labor, :stables, project: @project)
      stables = create(:monster, name: 'Augean Stables', stats: '{"filename": "stables-stats.tsv", "original_filename": "alpha-stables.tsv"}', labor: labor)
    
      retrieve(
        project_name: 'labors',
        model_name: 'monster',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'stats^@'
      )

      expect(last_response.status).to eq(200)

      monster_names = json_body[:models][:monster][:documents].values.map{|d| d[:name]}
      expect(monster_names).to eq(['Lernean Hydra'])
    end

    it 'can filter files with "equals"' do
      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, name: 'Nemean Lion', stats: '{"filename": "lion-stats.tsv", "original_filename": "alpha-lion.tsv"}', labor: labor)

      labor = create(:labor, :hydra, project: @project)
      hydra = create(:monster, name: 'Lernean Hydra', stats: nil, labor: labor)

      labor = create(:labor, :stables, project: @project)
      stables = create(:monster, name: 'Augean Stables', stats: '{"filename": "stables-stats.tsv", "original_filename": "alpha-stables.tsv"}', labor: labor)
    
      retrieve(
        project_name: 'labors',
        model_name: 'monster',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'stats=stables-stats.tsv'
      )

      expect(last_response.status).to eq(200)

      monster_names = json_body[:models][:monster][:documents].values.map{|d| d[:name]}
      expect(monster_names).to eq(['Augean Stables'])
    end

    it 'can filter booleans' do
      lion = create(:labor, :lion, completed: true, project: @project)
      hydra = create(:labor, :hydra, completed: false, project: @project)
      stables = create(:labor, :stables, completed: nil, project: @project)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'completed=true'
      )

      expect(last_response.status).to eq(200)
      expect(
        json_body[:models][:labor][:documents].values.map{|d| d[:name]}
      ).to eq(["Nemean Lion"])

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'completed=false'
      )

      expect(last_response.status).to eq(200)
      expect(
        json_body[:models][:labor][:documents].values.map{|d| d[:name]}
      ).to eq(["Lernean Hydra"])

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: "completed^@"
      )
      
      expect(last_response.status).to eq(200)
      expect(
        json_body[:models][:labor][:documents].values.map{|d| d[:name]}
      ).to eq(["Augean Stables"])
    end
  end

  context 'pagination' do
    it 'can order by an additional parameter across pages' do
      labor_list = []
      labor_list << create(:labor, name: "d", project: @project)
      labor_list << create(:labor, name: "a", project: @project)
      labor_list << create(:labor, name: "c", project: @project)
      labor_list << create(:labor, name: "b", project: @project)

      retrieve(
          project_name: 'labors',
          model_name: 'labor',
          record_names: 'all',
          attribute_names: 'all',
          order: 'updated_at',
          page: 1,
          page_size: 2,
      )

      expect(json_body[:models][:labor][:documents].keys).to eq([:d, :a])
    end

    it 'can order results for a total query' do
      labor_list = []
      labor_list << create(:labor, name: "a", updated_at: Time.now + 5, project: @project)
      labor_list << create(:labor, name: "c", updated_at: Time.now - 3, project: @project)
      labor_list << create(:labor, name: "b", updated_at: Time.now - 2, project: @project)

      labor_list_by_identifier = labor_list.sort_by { |n| n.name.to_s }

      retrieve(
          project_name: 'labors',
          model_name: 'labor',
          record_names: 'all',
          attribute_names: 'all',
      )

      names_by_identifier = labor_list_by_identifier.map(&:name).map(&:to_sym)
      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].keys).to eq(names_by_identifier)

      labor_list_by_updated_at = labor_list.sort_by(&:updated_at)
      retrieve(
          project_name: 'labors',
          model_name: 'labor',
          record_names: 'all',
          attribute_names: 'all',
          order: 'updated_at'
      )

      names_by_updated_at = labor_list_by_updated_at.map(&:name).map(&:to_sym)
      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].keys).to eq(names_by_updated_at)

      expect(names_by_updated_at).to_not eql(names_by_identifier)
    end

    it 'can page results' do
      labor_list = create_list(:labor, 9, project: @project)
      third_page_labors = labor_list.sort_by(&:name)[6..8]
      labor_with_prize = third_page_labors[1]
      prize_list = create_list(:prize, 3, labor: labor_with_prize)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        page: 3,
        page_size: 3
      )

      names = third_page_labors.map(&:name).map(&:to_sym)

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].keys).to eq(names)
      expect(json_body[:models][:labor][:documents][labor_with_prize.name.to_sym][:prize]).to match_array(prize_list.map(&:id))

      # check to make sure collapse_tables doesn't mess things up
      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        collapse_tables: true,
        page: 3,
        page_size: 3
      )

      expect(last_response.status).to eq(200)
      expect(json_body[:models][:labor][:documents].keys).to eq(names)
      expect(json_body[:models][:labor][:documents][labor_with_prize.name.to_sym][:prize]).to eq(nil)
    end

    it 'can page results with joined collections' do
      labor = create(:labor, :lion, project: @project)
      monster_list = create_list(:monster, 9, labor: labor)
      victim_list = monster_list.map do |monster|
        create_list(:victim, 2, monster: monster)
      end.flatten

      names = monster_list.sort_by(&:name)[6..8].map(&:name)

      retrieve(
        project_name: 'labors',
        model_name: 'monster',
        record_names: 'all',
        attribute_names: 'all',
        order: 'reference_monster',
        page: 3,
        page_size: 3
      )

      expect(json_body[:models][:monster][:documents].keys).to eq(names.map(&:to_sym))
    end

    it 'returns a count of total records for page 1' do
      labor_list = create_list(:labor, 9, project: @project)

      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        page: 1,
        page_size: 3
      )

      expect(json_body[:models][:labor][:count]).to eq(9)
    end

    it 'returns a descriptive error when no results are retrieved on paginated query' do
      lion = create(:labor, :lion)
      hydra = create(:labor, :hydra)
      stables = create(:labor, :stables)
      retrieve(
        project_name: 'labors',
        model_name: 'labor',
        record_names: 'all',
        attribute_names: 'all',
        filter: 'name~xyz123',
        page: 1,
        page_size: 10
      )

      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Page 1 not found"])
    end
  end

  context 'restriction' do
    it 'hides restricted records' do
      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, :lion, labor: labor)
      restricted_victim_list = create_list(:victim, 9, restricted: true, monster: lion)
      unrestricted_victim_list = create_list(:victim, 9, monster: lion)

      retrieve(
        project_name: 'labors',
        model_name: 'victim',
        record_names: 'all',
        attribute_names: 'all'
      )
      expect(last_response.status).to eq(200)
      expect(json_body[:models][:victim][:documents].keys.sort).to eq(unrestricted_victim_list.map(&:identifier).map(&:to_sym))
    end

    it 'hides the children of restricted records' do
      labor = create(:labor, :lion, project: @project)
      labor2 = create(:labor, :hydra, project: @project)
      lion = create(:monster, :lion, restricted: true, labor: labor)
      hydra = create(:monster, :hydra, restricted: false, labor: labor2)
      restricted_victim_list = create_list(:victim, 9, monster: lion)
      unrestricted_victim_list = create_list(:victim, 9, monster: hydra)

      retrieve(
        project_name: 'labors',
        model_name: 'victim',
        record_names: 'all',
        attribute_names: 'all'
      )
      expect(json_body[:models][:victim][:documents].keys.sort).to eq(unrestricted_victim_list.map(&:identifier).map(&:to_sym))
    end

    it 'conservatively hides if any ancestor is restricted' do
      labor = create(:labor, :lion, project: @project)
      labor2 = create(:labor, :hydra, project: @project)
      lion = create(:monster, :lion, restricted: true, labor: labor)
      hydra = create(:monster, :hydra, restricted: false, labor: labor2)

      # some of the victims are not restricted
      restricted_victim_list = create_list(:victim, 3, monster: lion, restricted: true)
      unrestricted_victim_list = create_list(:victim, 3, monster: lion, restricted: false)
      unrestricted_victim_list2 = create_list(:victim, 3, monster: lion, restricted: nil)

      # some of the victims are not restricted
      restricted_victim_list2 = create_list(:victim, 3, monster: hydra, restricted: true)
      unrestricted_victim_list3 = create_list(:victim, 3, monster: hydra, restricted: false)
      unrestricted_victim_list4 = create_list(:victim, 3, monster: hydra, restricted: nil)

      retrieve(
        project_name: 'labors',
        model_name: 'victim',
        record_names: 'all',
        attribute_names: 'all'
      )
      expect(json_body[:models][:victim][:documents].keys.sort).to match_array((unrestricted_victim_list3 + unrestricted_victim_list4).map(&:identifier).map(&:to_sym))
    end

    it 'shows restricted records to users with restricted permission' do
      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, :lion, restricted: true, labor: labor)
      restricted_victim_list = create_list(:victim, 9, restricted: true, monster: lion)
      unrestricted_victim_list = create_list(:victim, 9, monster: lion)

      retrieve(
        {
          project_name: 'labors',
          model_name: 'victim',
          record_names: 'all',
          attribute_names: 'all'
        },
        :privileged_editor
      )
      expect(json_body[:models][:victim][:documents].keys.sort).to eq(
        (
          unrestricted_victim_list + restricted_victim_list
        ).map(&:identifier).map(&:to_sym).sort
      )
    end

    it 'shows the children of restricted records to users with restricted permission' do
      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, :lion, restricted: true, labor: labor)
      hydra = create(:monster, :hydra, restricted: false, labor: labor)
      restricted_victim_list = create_list(:victim, 9, monster: lion)
      unrestricted_victim_list = create_list(:victim, 9, monster: hydra)

      retrieve(
        {
          project_name: 'labors',
          model_name: 'victim',
          record_names: 'all',
          attribute_names: 'all'
        },
        :privileged_editor
      )
      expect(json_body[:models][:victim][:documents].keys.sort).to eq(
        (
          unrestricted_victim_list + restricted_victim_list
        ).map(&:identifier).map(&:to_sym).sort
      )
    end

    it 'hides restricted attributes' do
      victim_list = create_list(:victim, 9, country: 'thrace')

      retrieve(
        project_name: 'labors',
        model_name: 'victim',
        record_names: 'all',
        attribute_names: 'all'
      )
      countries = json_body[:models][:victim][:documents].values.map{|victim| victim[:country]}
      expect(countries).to all(be_nil)
    end

    it 'shows restricted attributes to users with restricted permission' do
      victim_list = create_list(:victim, 9, country: 'thrace')

      retrieve(
        {
          project_name: 'labors',
          model_name: 'victim',
          record_names: 'all',
          attribute_names: [ 'country' ]
        },
        :privileged_editor
      )
      countries = json_body[:models][:victim][:documents].values.map{|victim| victim[:country]}
      expect(countries).to all(eq('thrace'))
    end
  end
end
