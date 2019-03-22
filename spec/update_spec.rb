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

  it 'can update a collection' do
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
    expect(json_body[:models][:project][:documents][:'The Two Labors of Hercules']).to eq(name: 'The Two Labors of Hercules', labor: [ 'Lernean Hydra', 'Nemean Lion' ])

    # check that it sets created_at and updated_at
    expect(Labors::Labor.select_map(:created_at)).to all( be_a(Time) )
    expect(Labors::Labor.select_map(:updated_at)).to all( be_a(Time) )
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
      expect(json_body[:models][:victim][:documents][new_name.to_sym]).to eq(name: new_name)

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
      expect(json_body[:models][:victim][:documents][:'Outis Koutsonadis'][:country]).to eq('thrace')

      victim.refresh
      expect(victim.country).to eq('thrace')
    end
  end
end
