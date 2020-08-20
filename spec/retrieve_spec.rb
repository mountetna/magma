describe RetrieveController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  def retrieve(post, user_type=:viewer)
    auth_header(user_type)
    json_post(:retrieve, post)
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
    expect(json_template[:attributes].map{|att_name,att| att.keys.sort}).to all(include( :attribute_class, :display_name, :name, :hidden))

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
      monster = create(:monster, :lion, stats: '{"filename": "stats.txt", "original_filename": ""}')

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

  context 'identifiers' do
    it 'allows grabbing the entire set of identifiers' do
      labors = create_list(:labor,3)
      monsters = create_list(:monster,3)
      prizes = create_list(:prize,3)
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
      labors = create_list(:labor,3)

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
      prizes = create_list(:prize,3)
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
      project = create(:project, name: 'The Twelve Labors of Hercules')
      labors = create_list(:labor, 3, project: project)

      retrieve(
        model_name: 'project',
        record_names: [ project.name ],
        attribute_names: [ 'labor' ],
        project_name: 'labors'
      )

      project_doc = json_body[:models][:project][:documents][project.name.to_sym]

      expect(project_doc).not_to be_nil
      expect(project_doc[:labor]).to match_array(labors.map(&:name))
    end

    it 'returns an empty list for empty collections' do
      project = create(:project, name: 'The Twelve Labors of Hercules')

      retrieve(
        model_name: 'project',
        record_names: [ project.name ],
        attribute_names: [ 'labor' ],
        project_name: 'labors'
      )

      project_doc = json_body[:models][:project][:documents][project.name.to_sym]

      expect(project_doc).not_to be_nil
      expect(project_doc[:labor]).to eq([])
    end
  end

  context 'tables' do
    it 'retrieves table associations' do
      lion = create(:labor, :lion)
      hydra = create(:labor, :hydra)
      stables = create(:labor, :stables)
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
      lion = create(:labor, :lion)
      hydra = create(:labor, :hydra)
      stables = create(:labor, :stables)
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
      labor_list = create_list(:labor, 12)
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
      expect(table.length).to eq(12)
    end

    it 'can retrieve a TSV of data without an identifier' do
      prize_list = create_list(:prize, 12)
      retrieve(
        project_name: 'labors',
        model_name: 'prize',
        record_names: 'all',
        attribute_names: 'all',
        format: 'tsv'
      )
      header, *table = CSV.parse(last_response.body, col_sep: "\t")

      expect(table.length).to eq(12)
    end

    it 'can retrieve a TSV of collection attribute' do
      project = create(:project, name: 'The Twelve Labors of Hercules')
      labors = create_list(:labor, 3, project: project)

      retrieve(
        model_name: 'project',
        record_names: [ project.name ],
        attribute_names: [ 'labor' ],
        project_name: 'labors',
        format: 'tsv'
      )

      header, *table = CSV.parse(last_response.body, col_sep: "\t")

      expect(table.length).to eq(1)
    end
  end

  context 'filtering' do
    it 'can use a filter' do
      lion = create(:labor, :lion)
      hydra = create(:labor, :hydra)
      stables = create(:labor, :stables)
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

    it 'can filter on numbers' do
      poison = create(:prize, name: 'poison', worth: 5)
      poop = create(:prize, name: 'poop', worth: 0)
      iou = create(:prize, name: 'iou', worth: 2)
      skin = create(:prize, name: 'skin', worth: 6)
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

    it 'can filter on dates' do
      old_labors = create_list(:labor, 3, year: DateTime.new(500))
      new_labors = create_list(:labor, 3, year: DateTime.new(2000))

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

    it 'can filter on updated_at, created_at' do
      Timecop.freeze(DateTime.new(500))
      old_labors = create_list(:labor, 3)

      Timecop.freeze(DateTime.new(2000))
      new_labors = create_list(:labor, 3)

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
  end

  context 'pagination' do
    it 'can page results' do
      labor_list = create_list(:labor, 9)
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
      monster_list = create_list(:monster, 9)
      victim_list = monster_list.map do |monster|
        create_list(:victim, 2, monster: monster)
      end.flatten

      names = monster_list.sort_by(&:name)[6..8].map(&:name)

      retrieve(
        project_name: 'labors',
        model_name: 'monster',
        record_names: 'all',
        attribute_names: 'all',
        page: 3,
        page_size: 3
      )

      expect(json_body[:models][:monster][:documents].keys).to eq(names.map(&:to_sym))
    end

    it 'returns a count of total records for page 1' do
      labor_list = create_list(:labor, 9)

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
      restricted_victim_list = create_list(:victim, 9, restricted: true)
      unrestricted_victim_list = create_list(:victim, 9)

      retrieve(
        project_name: 'labors',
        model_name: 'victim',
        record_names: 'all',
        attribute_names: 'all'
      )
      expect(json_body[:models][:victim][:documents].keys.sort).to eq(unrestricted_victim_list.map(&:identifier).map(&:to_sym))
    end

    it 'shows restricted records to users with restricted permission' do
      restricted_victim_list = create_list(:victim, 9, restricted: true)
      unrestricted_victim_list = create_list(:victim, 9)

      retrieve(
        {
          project_name: 'labors',
          model_name: 'victim',
          record_names: 'all',
          attribute_names: 'all'
        },
        :editor
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
        :editor
      )
      countries = json_body[:models][:victim][:documents].values.map{|victim| victim[:country]}
      expect(countries).to all(eq('thrace'))
    end
  end
end
