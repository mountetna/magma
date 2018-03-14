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
      model_name: 'labor',
      record_names: [],
      attribute_names: [],
      project_name: 'labors'
    )
    expect(last_response.status).to eq(200)
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
    json = json_body(last_response.body)

    # any model with an identifier returns all records
    expect(json[:models][:labor][:documents].keys).to eq(labors.map(&:name).map(&:to_sym))
    expect(json[:models][:monster][:documents].keys).to eq(monsters.map(&:name).map(&:to_sym))

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

    json = json_body(last_response.body)

    expect(json[:models][:labor][:documents]).to have_key(names.first)
    expect(json[:models][:labor][:documents]).not_to have_key(names.last)
  end

  it 'retrieves collections as a list of identifiers' do
    project = create(:project, name: 'The Twelve Labors of Hercules')
    labors = create_list(:labor, 3, project: project)

    retrieve(
      model_name: 'project',
      record_names: [ project.name ],
      attribute_names: [ 'labor' ],
      project_name: 'labors'
    )

    json = json_body(last_response.body)
    project_doc = json[:models][:project][:documents][project.name.to_sym]

    expect(project_doc).not_to be_nil
    expect(project_doc[:labor]).to eq(labors.map(&:name))
  end

  it 'returns an empty list for empty collections' do
    project = create(:project, name: 'The Twelve Labors of Hercules')

    retrieve(
      model_name: 'project',
      record_names: [ project.name ],
      attribute_names: [ 'labor' ],
      project_name: 'labors'
    )

    json = json_body(last_response.body)
    project_doc = json[:models][:project][:documents][project.name.to_sym]

    expect(project_doc).not_to be_nil
    expect(project_doc[:labor]).to eq([])
  end

  it 'can retrieve records by id if there is no identifier' do
    prizes = create_list(:prize,3)
    retrieve(
      project_name: 'labors',
      model_name: 'prize',
      record_names: prizes[0..1].map(&:id),
      attribute_names: 'all' 
    )

    json = json_body(last_response.body)

    expect(json[:models][:prize][:documents]).to have_key(prizes[0].id.to_s.to_sym)
    expect(json[:models][:prize][:documents]).not_to have_key(prizes[2].id.to_s.to_sym)
  end

  it 'can retrieve a TSV of data from the endpoint' do
    labor_list = create_list(:labor, 12)
    required_atts = ['name', 'number', 'completed']
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

  it 'can use a filter' do
    lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true)
    hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
    stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)
    retrieve(
      project_name: 'labors',
      model_name: 'labor',
      record_names: 'all',
      attribute_names: 'all',
      filter: 'name~L'
    )

    json = json_body(last_response.body)
    expect(last_response.status).to eq(200)
    expect(json[:models][:labor][:documents].count).to eq(2)
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

    json = json_body(last_response.body)
    prize_names = json[:models][:prize][:documents].values.map{|d| d[:name]}
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

    json = json_body(last_response.body)
    labor_names = json[:models][:labor][:documents].values.map{|d| d[:name]}
    expect(labor_names).to eq(new_labors.map(&:name))
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

    json = json_body(last_response.body)
    labor_names = json[:models][:labor][:documents].values.map{|d| d[:name]}
    expect(labor_names).to eq(new_labors.map(&:name))

    Timecop.return
  end

  it 'can page results' do
    labor_list = create_list(:labor, 9)
    names = labor_list.sort_by(&:name)[6..8].map(&:name)

    retrieve(
      project_name: 'labors',
      model_name: 'labor',
      record_names: 'all',
      attribute_names: 'all',
      page: 3,
      page_size: 3
    )

    json = json_body(last_response.body)
    expect(json[:models][:labor][:documents].keys).to eq(names.map(&:to_sym))
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

    json = json_body(last_response.body)
    expect(json[:models][:monster][:documents].keys).to eq(names.map(&:to_sym))
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

    json = json_body(last_response.body)
    expect(json[:models][:labor][:count]).to eq(9)
  end

  it 'retrieves table associations' do
    lion = create(:labor, name: 'Nemean Lion', number: 1, completed: true)
    hydra = create(:labor, name: 'Lernean Hydra', number: 2, completed: false)
    stables = create(:labor, name: 'Augean Stables', number: 5, completed: false)
    lion_prizes = create_list(:prize, 3, labor: lion)
    hydra_prizes = create_list(:prize, 3, labor: hydra)
    stables_prizes = create_list(:prize, 3, labor: stables)

    selected_prize_ids = (lion_prizes + hydra_prizes).map do |prize|
      prize.send(Labors::Prize.identity).to_s
    end.sort

    retrieve(
      project_name: 'labors',
      model_name: 'labor',
      record_names: [ 'Nemean Lion', 'Lernean Hydra' ],
      attribute_names: [ 'prize' ]
    )

    json = json_body(last_response.body)
    expect(json[:models][:labor][:documents].size).to eq(2)
    expect(json[:models][:prize][:documents].keys.sort.map(&:to_s)).to eq(selected_prize_ids)
  end
end
