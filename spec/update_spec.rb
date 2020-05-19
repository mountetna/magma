describe UpdateController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  def update(revisions, user_type=:editor)
    auth_header(user_type)
    json_post(:update, {project_name: 'labors', revisions: revisions})
  end

  it 'fails for non-editors' do
    lion = create(:monster, name: 'Nemean Lion', species: 'hydra')
    update(
      {
        monster: {
          'Nemean Lion': {
            species: 'lion'
          }
        }
      },
      :viewer
    )
    expect(last_response.status).to eq(403)
  end

  it 'updates the identifier' do
    project = create(:project, name: 'The Two Labors of Hercules')
    update(
      'project' => {
        'The Two Labors of Hercules' => {
          name: 'The Ten Labors of Hercules'
        }
      }
    )

    expect(last_response.status).to eq(200)
    expect(json_document(:project, 'The Ten Labors of Hercules')).to eq(name: 'The Ten Labors of Hercules')
  end

  it 'updates a string attribute' do
    # The actual validation is defined in spec/labors/models/monster.rb,
    lion = create(:monster, name: 'Nemean Lion', species: 'lion')
    update(
      monster: {
        'Nemean Lion': {
          species: 'panthera leo'
        }
      }
    )

    lion.refresh
    expect(last_response.status).to eq(200)
    expect(lion.species).to eq('panthera leo')
    expect(json_document(:monster,'Nemean Lion')).to eq(name: 'Nemean Lion', species: 'panthera leo')
  end

  it 'updates an integer attribute' do
    skin = create(:prize, name: 'skin', worth: 6)
    update(
      prize: {
        skin.id => {
          worth: 8
        }
      }
    )

    skin.refresh
    expect(last_response.status).to eq(200)
    expect(skin.worth).to eq(8)
    expect(json_document(:prize,skin.id.to_s)).to eq(worth: 8)
  end

  it 'updates a date-time attribute' do
    lion = create(:labor, name: 'Nemean Lion', year: '0002-01-01')
    update(
      labor: {
        'Nemean Lion': {
          year: '0003-01-01'
        }
      }
    )

    lion.refresh
    expect(last_response.status).to eq(200)
    expect(lion.year).to eq(Time.parse('0003-01-01'))
    expect(json_document(:labor,'Nemean Lion')).to eq(name: 'Nemean Lion', year: '0003-01-01T00:00:00+00:00')
  end

  it 'updates a foreign-key attribute' do
    lion = create(:labor, name: 'The Nemean Lion', year: '0002-01-01')
    hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01')

    monster = create(:monster, name: 'Lernean Hydra', labor: lion)
    update(
      monster: {
        'Lernean Hydra': {
          labor: 'The Lernean Hydra'
        }
      }
    )
    monster.refresh
    hydra.refresh
    expect(monster.labor).to eq(hydra)

    expect(last_response.status).to eq(200)
    expect(json_document(:monster,'Lernean Hydra')).to include(labor: 'The Lernean Hydra')
  end

  it 'updates a match' do
    entry = create(
      :codex, :lion, aspect: 'hide', tome: 'Bullfinch',
      lore: { type: 'String', value: 'fur' }
    )

    new_lore = { 'type' => 'String', 'value' => 'leather' }
    update(
      codex: {
        entry.id => {
          lore: new_lore
        }
      }
    )
    entry.refresh
    expect(entry.lore).to eq(new_lore)

    expect(last_response.status).to eq(200)
    expect(json_document(:codex, entry.id.to_s)).to eq(lore: new_lore.symbolize_keys)
  end

  it 'updates a file attribute' do
    Timecop.freeze(DateTime.new(500))
    lion = create(:monster, name: 'Nemean Lion', species: 'lion')

    update(
      monster: {
        'Nemean Lion' => {
          stats: 'stats.txt'
        }
      }
    )

    # the field is NOT updated here
    lion.refresh
    expect(lion.stats).to be_nil

    expect(last_response.status).to eq(200)

    # but we do get an upload url for Metis
    uri = URI.parse(json_document(:monster, 'Nemean Lion')[:stats][:upload_url])
    params = Rack::Utils.parse_nested_query(uri.query)
    expect(uri.host).to eq(Magma.instance.config(:storage)[:host])
    expect(uri.path).to eq('/labors/upload/magma/stats.txt')
    expect(params['X-Etna-Id']).to eq('magma')
    expect(params['X-Etna-Expiration']).to eq((Time.now + Magma.instance.config(:storage)[:upload_expiration]).iso8601)

    Timecop.return
  end

  it 'updates a collection' do
    project = create(:project, name: 'The Two Labors of Hercules')
    update(
      'project' => {
        'The Two Labors of Hercules' => {
          labor: [
            'Nemean Lion',
            'Lernean Hydra'
          ]
        }
      }
    )

    expect(last_response.status).to eq(200)
    expect(Labors::Labor.count).to be(2)
    expect(json_document(:project, 'The Two Labors of Hercules')).to eq(name: 'The Two Labors of Hercules', labor: [ 'Lernean Hydra', 'Nemean Lion' ])

    # check that it sets created_at and updated_at
    expect(Labors::Labor.select_map(:created_at)).to all( be_a(Time) )
    expect(Labors::Labor.select_map(:updated_at)).to all( be_a(Time) )
  end

  it 'updates a matrix' do
    labor = create(:labor, name: 'Nemean Lion')
    update(
      'labor' => {
        'Nemean Lion' => {
          contributions: [
            10, 10, 10, 10
          ]
        }
      }
    )

    # we get the new value back
    expect(last_response.status).to eq(200)
    expect(json_document(:labor, 'Nemean Lion')[:contributions]).to eq([10, 10, 10, 10])

    # the model has the new value
    labor.refresh
    expect(Labors::Labor.count).to be(1)
    expect(labor.contributions).to eq([10, 10, 10, 10])
  end

  it 'complains about incorrectly-sized matrix rows' do
    labor = create(:labor, name: 'Nemean Lion')
    update(
      'labor' => {
        'Nemean Lion' => {
          contributions: [
            10, 10
          ]
        }
      }
    )

    # we get the new value back
    expect(last_response.status).to eq(422)
    expect(json_body[:errors]).to eq(["Improper matrix row size"])

    # the model has the same value
    labor.refresh
    expect(Labors::Labor.count).to be(1)
    expect(labor.contributions).to be_nil
  end

  it 'fails on validation checks' do
    # The actual validation is defined in spec/labors/models/monster.rb,
    lion = create(:monster, name: 'Nemean Lion', species: 'lion')
    update(
      monster: {
        'Nemean Lion': {
          species: 'Lion'
        }
      }
    )

    lion.refresh
    expect(last_response.status).to eq(422)
    expect(lion.species).to eq('lion')
  end

  context 'restriction' do
    it 'prevents updates to a restricted record by a restricted user' do
      orig_name = 'Outis Koutsonadis'
      new_name  = 'Outis Koutsomadis'
      restricted_victim = create(:victim, name: orig_name, restricted: true)

      update(
        {
          victim: {
            orig_name => {
              name: new_name
            }
          }
        },
        :restricted_editor
      )
      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Cannot revise restricted victim '#{orig_name}'"])

      restricted_victim.refresh
      expect(restricted_victim.name).to eq(orig_name)
    end

    it 'allows updates to a restricted record by an unrestricted user' do
      orig_name = 'Outis Koutsonadis'
      new_name  = 'Outis Koutsomadis'
      restricted_victim = create(:victim, name: orig_name, restricted: true)

      update(
        {
          victim: {
            orig_name => {
              name: new_name
            }
          }
        },
        :editor
      )
      expect(last_response.status).to eq(200)
      expect(json_document(:victim,new_name)).to eq(name: new_name)

      restricted_victim.refresh
      expect(restricted_victim.name).to eq(new_name)
    end

    it 'prevents updates to a restricted attribute by a restricted user' do
      victim = create(:victim, name: 'Outis Koutsonadis', country: 'nemea')

      update(
        {
          victim: {
            'Outis Koutsonadis': {
              country: 'thrace'
            }
          }
        },
        :restricted_editor
      )
      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Cannot revise restricted attribute :country on victim 'Outis Koutsonadis'"])

      victim.refresh
      expect(victim.country).to eq('nemea')
    end

    it 'allows updates to a restricted attribute by an unrestricted user' do
      victim = create(:victim, name: 'Outis Koutsonadis', country: 'nemea')

      update(
        {
          victim: {
            'Outis Koutsonadis': {
              country: 'thrace'
            }
          }
        },
        :editor
      )
      expect(last_response.status).to eq(200)
      expect(json_document(:victim,'Outis Koutsonadis')).to include(country: 'thrace')

      victim.refresh
      expect(victim.country).to eq('thrace')
    end
  end
end
