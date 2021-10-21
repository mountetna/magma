require 'json'

describe UpdateController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    route_payload = JSON.generate([
      {:method=>"POST", :route=>"/:project_name/files/copy", :name=>"file_bulk_copy", :params=>["project_name"]}
    ])
    stub_request(:options, 'https://metis.test').
    to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})

    route_payload = JSON.generate([
      {:success=>true}
    ])
    stub_request(:post, /https:\/\/metis.test\/labors\/files\/copy?/).
      to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})
    @project = create(:project, name: 'The Twelve Labors of Hercules')
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

  it 'updates updated_at' do
    now = Time.now
    later = now + 1500
    Timecop.freeze(now)

    Timecop.freeze(later)
    update(
      'project' => {
        'The Twelve Labors of Hercules' => {
          name: 'The Ten Labors of Hercules'
        }
      }
    )

    expect(last_response.status).to eq(200)
    expect(json_document(:project, 'The Ten Labors of Hercules')).to eq(name: 'The Ten Labors of Hercules')

    # the update happened
    expect(Labors::Project.count).to eq(1)
    @project.refresh
    expect(@project.name).to eq('The Ten Labors of Hercules')

    # we updated updated_at
    expect(@project.updated_at).to be_within(0.001).of(later)
    Timecop.return
  end

  it 'updates the identifier' do
    update(
      'project' => {
        'The Twelve Labors of Hercules' => {
          name: 'The Ten Labors of Hercules'
        }
      }
    )

    expect(last_response.status).to eq(200)
    expect(json_document(:project, 'The Ten Labors of Hercules')).to eq(name: 'The Ten Labors of Hercules')
    expect(Labors::Project.count).to eq(1)
    @project.refresh
    expect(@project.name).to eq('The Ten Labors of Hercules')
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
    #expect(json_document(:prize,skin.id.to_s)).to eq(worth: 8)
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

  it 'empties a date-time attribute' do
    lion = create(:labor, name: 'Nemean Lion', year: '0002-01-01')
    update(
      labor: {
        'Nemean Lion': {
          year: nil
        }
      }
    )

    lion.refresh
    expect(last_response.status).to eq(200)
    expect(lion.year).to eq(nil)
    expect(json_document(:labor,'Nemean Lion')).to eq(name: 'Nemean Lion', year: nil)
  end

  context 'linking records' do
    context 'from the "child" record' do
      it 'updates a parent attribute for parent-child' do
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra', labor: hydra)
        update(
          monster: {
            'Lernean Hydra': {
              labor: 'The Lernean Hydra'
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:monster,'Lernean Hydra')).to include(labor: 'The Lernean Hydra')

        monster.refresh
        hydra.refresh
        expect(monster.labor).to eq(hydra)
      end

      it 'updates a parent attribute for parent-collection' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0002-01-01', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01')

        expect(@project.labor.count).to eq(1)

        update(
          'project' => {
            'The Twelve Labors of Hercules' => {
              labor: [
                'The Nemean Lion',
                'The Lernean Hydra'
              ]
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:project,'The Twelve Labors of Hercules')).to include(labor: [ 'The Nemean Lion', 'The Lernean Hydra' ])

        @project.refresh
        lion.refresh
        hydra.refresh
        expect(@project.labor.count).to eq(2)
        expect(hydra.project).to eq(@project)
      end

      it 'updates a link attribute when link exists in the graph' do
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra', labor: hydra)
        habitat = create(:habitat, name: 'Underground', project: @project)

        expect(monster.habitat).to eq(nil)

        update(
          monster: {
            'Lernean Hydra': {
              habitat: 'Underground'
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:monster,'Lernean Hydra')).to include(habitat: 'Underground')

        # the links are added in both directions
        monster.refresh
        habitat.refresh
        expect(monster.habitat).to eq(habitat)
        expect(habitat.monster).to eq([monster])
      end

      it 'updates a link collection' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0003-01-01', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        hydra_monster = create(:monster, name: 'Lernean Hydra', labor: hydra)
        habitat = create(:habitat, name: 'Underground', project: @project)
        lion_monster = create(:monster, name: 'Nemean Lion', labor: lion, habitat: habitat)

        expect(hydra_monster.habitat).to eq(nil)
        expect(habitat.monster).to eq([lion_monster])

        update(
          monster: {
            'Lernean Hydra': {
              habitat: 'Underground'
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:monster,'Lernean Hydra')).to include(habitat: 'Underground')

        # the links are added in both directions
        hydra_monster.refresh
        habitat.refresh
        expect(hydra_monster.habitat).to eq(habitat)
        expect(habitat.monster).to match_array([lion_monster, hydra_monster])
      end
    end

    context 'from the "parent" or "link model" record' do
      it 'creates new child records for parent-collection' do
        expect(Labors::Labor.count).to be(0)

        update(
          'project' => {
            'The Twelve Labors of Hercules' => {
              labor: [
                'The Nemean Lion',
                'The Lernean Hydra'
              ]
            }
          }
        )

        # we have created some new records
        expect(Labors::Labor.count).to be(2)
        expect(Labors::Labor.select_map(:created_at)).to all( be_a(Time) )
        expect(Labors::Labor.select_map(:updated_at)).to all( be_a(Time) )

        # the labors are linked to the project
        @project.refresh
        expect(@project.labor.count).to eq(2)
        expect(Labors::Labor.first.project).to eq(@project)
        expect(Labors::Labor.last.project).to eq(@project)

        # the updated record is returned
        expect(last_response.status).to eq(200)
        expect(json_document(:project, 'The Twelve Labors of Hercules')[:labor]).to match_array([ 'The Lernean Hydra', 'The Nemean Lion' ])
      end

      it 'updates a collection from existing records for parent-collection' do
        habitat = create(:habitat, name: 'Underground', project: @project)

        lion = create(:labor, name: 'The Nemean Lion', year: '0002-01-01')
        lion_monster = create(:monster, name: 'Nemean Lion', labor: lion, habitat: habitat)

        expect(Labors::Labor.count).to be(1)
        expect(@project.labor.count).to eq(0)

        update(
          'project' => {
            'The Twelve Labors of Hercules' => {
              labor: [
                'The Nemean Lion'
              ]
            }
          }
        )

        # No new records created
        expect(Labors::Labor.count).to be(1)

        # the labor is linked to the project
        @project.refresh
        lion.refresh
        expect(@project.labor.count).to eq(1)
        expect(@project.labor).to eq([ lion ])
        expect(lion.project).to eq(@project)

        # the updated record is returned
        expect(last_response.status).to eq(200)
        expect(json_document(:project, 'The Twelve Labors of Hercules')[:labor]).to match_array([ 'The Nemean Lion' ])
      end

      it 'creates a new child record for parent-child' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0002-01-01', project: @project)

        expect(Labors::Monster.count).to be(0)

        update(
          labor: {
            'The Nemean Lion': {
              monster: 'Nemean Lion'
            }
          }
        )

        # we have created a new record
        expect(Labors::Monster.count).to be(1)
        monster = Labors::Monster.first
        expect(monster.name).to eq('Nemean Lion')

        # the links are created in both directions
        lion.refresh
        expect(lion.monster).to eq(monster)
        expect(monster.labor).to eq(lion)

        # the updated record is returned
        expect(last_response.status).to eq(200)
        expect(json_document(:labor, 'The Nemean Lion')).to include(monster: 'Nemean Lion')
      end

      it 'updates a child from an existing record for parent-child' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0002-01-01', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra', labor: lion)

        expect(Labors::Monster.count).to be(1)
        expect(lion.monster).to eq(monster)
        expect(hydra.monster).to eq(nil)

        update(
          labor: {
            'The Lernean Hydra': {
              monster: 'Lernean Hydra'
            }
          }
        )

        # we have not created a new record
        expect(Labors::Monster.count).to be(1)

        # the links are updated in both directions
        hydra.refresh
        lion.refresh
        monster.refresh
        expect(lion.monster).to eq(nil)
        expect(hydra.monster).to eq(monster)
        expect(monster.labor).to eq(hydra)

        # the updated record is returned
        expect(last_response.status).to eq(200)
        expect(json_document(:labor, 'The Lernean Hydra')).to include(monster: 'Lernean Hydra')
      end

      it 'from the parent for parent-child with multiple revisions' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0002-01-01', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        lion_monster = create(:monster, name: 'Nemean Lion', labor: hydra)
        hydra_monster = create(:monster, name: 'Lernean Hydra', labor: lion)

        expect(Labors::Labor.count).to eq(2)
        expect(Labors::Monster.count).to eq(2)

        update(
          labor: {
            'The Lernean Hydra': {
              monster: 'Lernean Hydra'
            },
            'The Nemean Lion': {
              monster: 'Nemean Lion'
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:labor,'The Lernean Hydra')).to include(monster: 'Lernean Hydra')
        expect(json_document(:labor,'The Nemean Lion')).to include(monster: 'Nemean Lion')

        expect(Labors::Labor.count).to eq(2)
        expect(Labors::Monster.count).to eq(2)

        lion_monster.refresh
        lion.refresh
        hydra_monster.refresh
        hydra.refresh
        expect(lion_monster.labor).to eq(lion)
        expect(lion.monster).to eq(lion_monster)
        expect(hydra_monster.labor).to eq(hydra)
        expect(hydra.monster).to eq(hydra_monster)
      end

      it 'can add a collection from a linked model and create new records' do
        habitat = create(:habitat, name: 'Underground', project: @project)

        expect(Labors::Monster.count).to eq(0)

        update(
          habitat: {
            'Underground': {
              monster: ['Nemean Lion']
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:habitat,'Underground')).to include(monster: [ 'Nemean Lion' ])

        # the links are added in both directions
        expect(Labors::Monster.count).to eq(1)
        monster = Labors::Monster.first
        habitat.refresh
        expect(monster.habitat).to eq(habitat)
        expect(habitat.monster).to eq([ monster ])
      end

      it 'can add a collection from a linked model to existing records' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0002-01-01', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        lion_monster = create(:monster, name: 'Nemean Lion', labor: lion)
        hydra_monster = create(:monster, name: 'Lernean Hydra', labor: hydra)

        habitat = create(:habitat, name: 'Underground', project: @project)

        expect(lion_monster.habitat).to eq(nil)
        expect(hydra_monster.habitat).to eq(nil)
        expect(Labors::Monster.count).to eq(2)

        update(
          habitat: {
            'Underground': {
              monster: ['Nemean Lion', 'Lernean Hydra']
            }
          }
        )

        expect(Labors::Monster.count).to eq(2)
        expect(last_response.status).to eq(200)
        expect(json_document(:habitat,'Underground')).to include(monster: [ 'Nemean Lion', 'Lernean Hydra' ])

        # the links are added in both directions
        lion_monster.refresh
        hydra_monster.refresh
        habitat.refresh
        expect(lion_monster.habitat).to eq(habitat)
        expect(hydra_monster.habitat).to eq(habitat)
        expect(habitat.monster).to match_array([ lion_monster, hydra_monster ])
      end
    end

    context 'can create disconnected records' do
      it 'via the child itself for parent-child' do
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra', labor: hydra)

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(1)

        update(
          monster: {
            'Lernean Hydra': {
              labor: nil
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:monster,'Lernean Hydra')).to include(labor: nil)

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(1)

        monster.refresh
        hydra.refresh
        expect(monster.labor).to eq(nil)
        expect(hydra.monster).to eq(nil)
      end

      it 'from the parent for parent-child' do
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra', labor: hydra)

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(1)

        update(
          labor: {
            'The Lernean Hydra': {
              monster: nil
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:labor,'The Lernean Hydra')).to include(monster: nil)

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(1)

        monster.refresh
        hydra.refresh
        expect(monster.labor).to eq(nil)
        expect(hydra.monster).to eq(nil)
      end

      it 'from the parent when switching children, for parent-child' do
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        lion_monster = create(:monster, name: 'Nemean Lion', labor: hydra)
        hydra_monster = create(:monster, name: 'Lernean Hydra')

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(2)

        update(
          labor: {
            'The Lernean Hydra': {
              monster: 'Lernean Hydra'
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:labor,'The Lernean Hydra')).to include(monster: 'Lernean Hydra')

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(2)

        lion_monster.refresh
        hydra_monster.refresh
        hydra.refresh
        expect(lion_monster.labor).to eq(nil)
        expect(hydra_monster.labor).to eq(hydra)
        expect(hydra.monster).to eq(hydra_monster)
      end

      it 'from the child itself for parent-collection' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0003-01-01', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        @project.refresh

        expect(@project.labor.count).to eq(2)

        update(
          labor: {
            'The Lernean Hydra': {
              project: nil
            }
          }
        )

        # we have not created any new records
        expect(Labors::Labor.count).to be(2)

        # the lion labor is still linked to the project
        @project.refresh
        lion.refresh
        hydra.refresh
        expect(@project.labor.count).to eq(1)
        expect(@project.labor.first).to eq(lion)
        expect(lion.project).to eq(@project)
        expect(hydra.project).to eq(nil)

        # the updated record is returned
        expect(last_response.status).to eq(200)
        expect(json_document(:labor, 'The Lernean Hydra')).to include(project: nil)
      end

      it 'when updating the parent collection for parent-collection' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0003-01-01', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        @project.refresh

        expect(@project.labor.count).to eq(2)

        update(
          'project' => {
            'The Twelve Labors of Hercules' => {
              labor: [
                'The Nemean Lion'
              ]
            }
          }
        )

        # we have not created any new records
        expect(Labors::Labor.count).to be(2)

        # the first labors is still linked to the project
        @project.refresh
        lion.refresh
        hydra.refresh
        expect(@project.labor.count).to eq(1)
        expect(@project.labor.first).to eq(lion)
        expect(lion.project).to eq(@project)
        expect(hydra.project).to eq(nil)

        # the updated record is returned
        expect(last_response.status).to eq(200)
        expect(json_document(:project, 'The Twelve Labors of Hercules')[:labor]).to match_array([ 'The Nemean Lion' ])
      end

      it 'when setting the collection to [], from a parent' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0003-01-01', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        @project.refresh

        expect(@project.labor.count).to eq(2)

        update(
          'project' => {
            'The Twelve Labors of Hercules' => {
              labor: []
            }
          }
        )

        # we have not deleted any records
        expect(Labors::Labor.count).to be(2)

        # No labors are linked to the project
        @project.refresh
        lion.refresh
        hydra.refresh
        expect(@project.labor.count).to eq(0)
        expect(lion.project).to eq(nil)
        expect(hydra.project).to eq(nil)

        # the updated record is returned
        expect(last_response.status).to eq(200)
        expect(json_document(:project, 'The Twelve Labors of Hercules')[:labor]).to match_array([ ])
      end

      it 'from the child of a link_model' do
        habitat = create(:habitat, name: 'Underground', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra', habitat: habitat)

        expect(monster.habitat).to eq(habitat)
        expect(habitat.monster).to eq([ monster ])

        update(
          monster: {
            'Lernean Hydra': {
              habitat: nil
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:monster,'Lernean Hydra')).to include(habitat: nil)

        # the link has been removed
        monster.refresh
        habitat.refresh
        expect(monster.habitat).to eq(nil)
        expect(habitat.monster).to eq([])
      end

      it 'via the link model' do
        habitat = create(:habitat, name: 'Underground', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra', habitat: habitat, labor: hydra)

        expect(monster.habitat).to eq(habitat)
        expect(habitat.monster).to eq([ monster ])

        update(
          habitat: {
            'Underground': {
              monster: []
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:habitat,'Underground')).to include(monster: [])

        # the link has been removed
        monster.refresh
        habitat.refresh
        expect(monster.habitat).to eq(nil)
        expect(habitat.monster).to eq([])
      end
    end

    context 'can re-attach disconnected records' do
      it 'via the child itself for parent-child' do
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra')

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(1)

        expect(monster.labor).to eq(nil)
        expect(hydra.monster).to eq(nil)

        update(
          monster: {
            'Lernean Hydra': {
              labor: 'The Lernean Hydra'
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:monster,'Lernean Hydra')).to include(labor: 'The Lernean Hydra')

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(1)

        monster.refresh
        hydra.refresh
        expect(monster.labor).to eq(hydra)
        expect(hydra.monster).to eq(monster)
      end

      it 'via a parent record for parent-child' do
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra')

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(1)

        expect(monster.labor).to eq(nil)
        expect(hydra.monster).to eq(nil)

        update(
          labor: {
            'The Lernean Hydra': {
              monster: 'Lernean Hydra'
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:labor,'The Lernean Hydra')).to include(monster: 'Lernean Hydra')

        expect(Labors::Labor.count).to eq(1)
        expect(Labors::Monster.count).to eq(1)

        monster.refresh
        hydra.refresh
        expect(monster.labor).to eq(hydra)
        expect(hydra.monster).to eq(monster)
      end

      it 'via a child in parent-collection' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0002-01-01')
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        expect(Labors::Labor.count).to eq(2)

        expect(lion.project).to eq(nil)
        expect(hydra.project).to eq(@project)
        expect(@project.labor).to eq([ hydra ])

        update(
          labor: {
            'The Nemean Lion': {
              project: 'The Twelve Labors of Hercules'
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:labor,'The Nemean Lion')).to include(project: 'The Twelve Labors of Hercules')

        expect(Labors::Labor.count).to eq(2)

        lion.refresh
        hydra.refresh
        @project.refresh
        expect(lion.project).to eq(@project)
        expect(hydra.project).to eq(@project)
        expect(@project.labor).to match_array([ hydra, lion ])
      end

      it 'via a parent in parent-collection' do
        lion = create(:labor, name: 'The Nemean Lion', year: '0002-01-01', project: nil)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        expect(Labors::Labor.count).to eq(2)

        expect(lion.project).to eq(nil)
        expect(hydra.project).to eq(@project)
        expect(@project.labor).to eq([ hydra ])

        update(
          project: {
            'The Twelve Labors of Hercules': {
              labor: [
                'The Lernean Hydra',
                'The Nemean Lion'
              ]
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:project,'The Twelve Labors of Hercules')).to include(labor: [ 'The Lernean Hydra', 'The Nemean Lion' ])

        expect(Labors::Labor.count).to eq(2)

        lion.refresh
        hydra.refresh
        @project.refresh
        expect(lion.project).to eq(@project)
        expect(hydra.project).to eq(@project)
        expect(@project.labor).to match_array([ hydra, lion ])
      end

      it 'via the child of a link model' do
        habitat = create(:habitat, name: 'Underground', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra')

        expect(monster.habitat).to eq(nil)
        expect(habitat.monster).to eq([])

        update(
          monster: {
            'Lernean Hydra': {
              habitat: 'Underground'
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:monster,'Lernean Hydra')).to include(habitat: 'Underground')

        # the link has been added in both directions
        monster.refresh
        habitat.refresh
        expect(monster.habitat).to eq(habitat)
        expect(habitat.monster).to eq([ monster ])
      end

      it 'via the link model' do
        habitat = create(:habitat, name: 'Underground', project: @project)
        hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01', project: @project)

        monster = create(:monster, name: 'Lernean Hydra')

        expect(monster.habitat).to eq(nil)
        expect(habitat.monster).to eq([])

        update(
          habitat: {
            'Underground': {
              monster: [ 'Lernean Hydra' ]
            }
          }
        )

        expect(last_response.status).to eq(200)
        expect(json_document(:habitat,'Underground')).to include(monster: [ 'Lernean Hydra' ])

        # the link has been added in both directions
        monster.refresh
        habitat.refresh
        expect(monster.habitat).to eq(habitat)
        expect(habitat.monster).to eq([ monster ])
      end
    end

    context 'trying to re-attach disconnected records but not to the graph throws exception for' do
      xit 'disconnected parent, parent-collection' do
      end

      xit 'non-existent parent record, parent-collection' do
      end

      xit 'disconnected parent, parent-child' do
      end

      xit 'non-existent parent record, parent-child' do
      end

      xit 'non-existent link model' do
      end

      xit 'disconnected link model' do
      end
    end

      # child => parent
      # collection => parent
      # table => parent
      #
      # link_record(s) exist
      #   new value =>
      #     new_value record(s) exist => set parent to record_name
      #     new_value record(s) don't exist => create and set parent to record_name
      #     old_value record(s) NOT in new_value => set parent to nil
      #   nil => set parent for all old records to nil
      #
      # link_record(s) don't exist
      #   new value =>
      #     new_value record(s) exist => set parent to record_name
      #     new_value record(s) don't exist => create and set parent to record_name
      #   nil => do nothing
      #
      # child => link
      # collection => link
      # table => link
      #
      # link_record(s) exist
      #   new value =>
      #     new_value record(s) exist => set parent to record_name
      #     new_value record(s) don't exist => validation error
      #     old_value record(s) NOT in new_value => set parent to nil
      #   nil => set parent for all old records to nil
      #
      # link_record(s) don't exist
      #   new value =>
      #     new_value record(s) exist => set parent to record_name
      #     new_value record(s) won't exist after this update => validation error
      #   nil => do nothing
      #
      # parent => child
      # parent => collection
      # parent => table
      # link => child
      # link => collection
      # link => table
      #
      # link_record(s) don't exist
      #   new_value =>
      #     new_value record exists => set new_value
      #     new_value record won't exists => validation error
      #   nil => do nothing
      #
      # link_record(s) exist
      #   new_value =>
      #     new_value record exists => set new_value
      #     new_value record won't exist => validation error
      #
      # link
      #
      # new_value =>
      #   new_value record exists => set new_value
      #   new_value record won't exist => validation error

    context 'table attributes' do
      before(:each) do
        @apple_of_joy = { name: 'apple of joy', worth: 2000 }
        @apple_of_discord = { name: 'apple of discord', worth: 3000 }
      end

      it 'updates a table' do
        labor = create(:labor, name: 'The Golden Apples of the Hesperides', project: @project)
        update(
          'labor' => {
            'The Golden Apples of the Hesperides' => {
              prize: [
                '::temp1',
                '::temp2'
              ]
            },
          },
          'prize' => {
            '::temp1' => @apple_of_joy,
            '::temp2' => @apple_of_joy
          }
        )
        expect(last_response.status).to eq(200)

        # we have created some new records
        expect(Labors::Prize.count).to eq(2)

        # the prizes are linked to the labor
        labor.refresh
        expect(labor.prize.count).to eq(2)

        # the updated record is returned
        expect(json_document(:labor, 'The Golden Apples of the Hesperides')[:prize]).to match_array(Labors::Prize.select_map(:id))
      end

      it 'updates a table for a new record' do
        update(
          'labor' => {
            'The Golden Apples of the Hesperides' => {
              prize: [
                '::temp1',
                '::temp2'
              ]
            },
          },
          'prize' => {
            '::temp1' => @apple_of_joy,
            '::temp2' => @apple_of_joy
          }
        )
        expect(last_response.status).to eq(200)

        # we have created some new records
        expect(Labors::Prize.count).to eq(2)

        # the prizes are linked to the labor
        labor = Labors::Labor.first
        expect(labor.prize.count).to eq(2)

        # the updated record is returned
        expect(json_document(:labor, 'The Golden Apples of the Hesperides')[:prize]).to match_array(Labors::Prize.select_map(:id))
      end

      it 'appends to an existing table' do
        labor = create(:labor, name: 'The Golden Apples of the Hesperides', project: @project)
        apples = create_list(:prize, 3, @apple_of_discord.merge(labor: labor))
        update(
          'prize' => {
            '::temp1' => @apple_of_joy.merge(labor: 'The Golden Apples of the Hesperides'),
            '::temp2' => @apple_of_joy.merge(labor: 'The Golden Apples of the Hesperides')
          }
        )

        # we have created some new records
        expect(Labors::Prize.count).to eq(5)

        # the prizes are linked to the labor
        labor.refresh
        expect(labor.prize.map(&:name)).to match_array([ 'apple of joy' ] * 2 + [ 'apple of discord' ] * 3)

        # the updated record is returned
        expect(last_response.status).to eq(200)
        expect(json_body[:models][:prize][:documents].values.map{|p|p[:name]}).to eq(['apple of joy']*2)
      end

      it 'replaces an existing table' do
        lion_labor = create(:labor, name: 'The Nemean Lion', project: @project)
        hide = create(:prize, name: 'hide', labor: lion_labor)

        apple_labor = create(:labor, name: 'The Golden Apples of the Hesperides', project: @project)
        apples = create_list(:prize, 3, @apple_of_discord.merge(labor: apple_labor))

        update(
          'labor' => {
            'The Golden Apples of the Hesperides' => {
              prize: [
                '::temp1',
                '::temp2'
              ]
            },
          },
          'prize' => {
            '::temp1' => @apple_of_joy,
            '::temp2' => @apple_of_joy
          }
        )

        # we have created some new records replacing the old
        expect(Labors::Prize.count).to eq(3)

        # the new prizes are linked to the labor
        apple_labor.refresh
        expect(apple_labor.prize.count).to eq(2)
        expect(apple_labor.prize.map(&:name)).to all( eq('apple of joy') )

        # tables we did not update are intact
        lion_labor.refresh
        expect(lion_labor.prize.count).to eq(1)
        expect(lion_labor.prize.map(&:name)).to all( eq('hide') )

        # the updated record is returned
        expect(last_response.status).to eq(200)
        expect(json_document(:labor, 'The Golden Apples of the Hesperides')[:prize]).to match_array(apple_labor.prize.map(&:id))
      end
    end
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
    expect(entry.lore.to_hash).to eq(new_lore)

    expect(last_response.status).to eq(200)
    expect(json_document(:codex, entry.id.to_s)).to eq(lore: new_lore.symbolize_keys)

    # Make sure the Metis copy endpoint was not called
    expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
    with(query: hash_including({
      "X-Etna-Headers": "revisions"
    }))
  end

  context 'file attributes' do
    it 'fails the update when the bulk copy request fails' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      # May be overkill ... but making sure each of the anticipated
      #   exceptions from Metis bulk_copy results in a failed Magma update.
      bad_request_statuses = [400, 403, 404, 422, 500]
      req_counter = 1
      bad_request_statuses.each do |status|
        stub_request(:post, /https:\/\/metis.test\/labors\/files\/copy/).
          to_return(status: status, body: '{}')

        update(
          monster: {
            'Nemean Lion' => {
              stats: {
                path: 'metis://labors/files/lion-stats.txt'
              }
            }
          }
        )
        lion.refresh
        expect(lion.stats).to eq nil  # Did not change from the create state
        expect(last_response.status).to eq(422)

        expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
          with(query: hash_including({
            "X-Etna-Headers": "revisions"
          })).times(req_counter)
        req_counter += 1
      end

      Timecop.return
    end

    it 'marks a file as blank' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      update(
        monster: {
          'Nemean Lion' => {
            stats: {
              path: '::blank'
            }
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.stats.to_json).to eq({
        location: "::blank",
        filename: "::blank",
        original_filename: "::blank"
      }.to_json)

      expect(last_response.status).to eq(200)

      # and we do not get an upload url for Metis
      expect(json_document(:monster, 'Nemean Lion')[:stats][:path]).to eq('::blank')
      expect(json_document(:monster, 'Nemean Lion')[:stats][:url]).to be_nil

      # Make sure the Metis copy endpoint was not called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'removes a file reference' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion', stats: '{"filename": "monster-Nemean Lion-lion-stats.txt", "original_filename": ""}')

      update(
        monster: {
          'Nemean Lion' => {
            stats: {
              path: nil
            }
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.stats.to_json).to eq({
        location: nil,
        filename: nil,
        original_filename: nil
      }.to_json)

      expect(last_response.status).to eq(200)

      # and we do not get an upload url for Metis
      expect(json_document(:monster, 'Nemean Lion')[:stats]).to be_nil

      # Make sure the Metis copy endpoint was not called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'removes a file reference using ::blank' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion', stats: '{"filename": "monster-Nemean Lion-lion-stats.txt", "original_filename": ""}')

      update(
        monster: {
          'Nemean Lion' => {
            stats: {
              path: '::blank'
            }
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.stats.to_json).to eq({
        location: "::blank",
        filename: "::blank",
        original_filename: "::blank"
      }.to_json)

      expect(last_response.status).to eq(200)

      # and we do not get an upload url for Metis
      expect(json_document(:monster, 'Nemean Lion')[:stats]).to eq({
        path: '::blank'
      })

      # Make sure the Metis copy endpoint was not called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'returns a temporary Metis path when using ::temp' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      update(
        monster: {
          'Nemean Lion' => {
            stats: {
              path: '::temp'
            }
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.stats).to eq(nil)

      expect(last_response.status).to eq(200)

      # but we do get an upload url for Metis
      upload_url = json_document(:monster, 'Nemean Lion')[:stats][:path]
      expect(upload_url.
        start_with?('https://metis.test/labors/upload/magma/tmp-')).to eq(true)
      expect(upload_url.
        include?('X-Etna-Signature=')).to eq(true)

      # Make sure the Metis copy endpoint was not called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'links a file from metis' do
      Timecop.freeze(DateTime.new(500))
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')
      update(
        monster: {
          'Nemean Lion' => {
            stats: {
              path: 'metis://labors/files/lion-stats.txt',
              original_filename: 'original-file.txt'
            }
          }
        }
      )

      expect(last_response.status).to eq(200)

      lion.refresh
      expect(lion.stats.to_json).to eq({
        location: "metis://labors/files/lion-stats.txt",
        filename: "monster-Nemean Lion-stats.txt",
        original_filename: "original-file.txt"
      }.to_json)

      # but we do get an download url for Metis
      uri = URI.parse(json_document(:monster, 'Nemean Lion')[:stats][:url])
      params = Rack::Utils.parse_nested_query(uri.query)
      expect(uri.host).to eq(Magma.instance.config(:storage)[:host])
      expect(uri.path).to eq('/labors/download/magma/monster-Nemean%20Lion-stats.txt')
      expect(params['X-Etna-Id']).to eq('magma')
      expect(params['X-Etna-Expiration']).to eq((Time.now + Magma.instance.config(:storage)[:download_expiration]).iso8601)

      expect(json_document(:monster, 'Nemean Lion')[:stats].key?(:path)).to eq (true)
      expect(json_document(:monster, 'Nemean Lion')[:stats].key?(:original_filename)).to eq (true)

      # Make sure the Metis copy endpoint was called
      expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
        with(query: hash_including({
          "X-Etna-Headers": "revisions"
        }), body: hash_including({
          "revisions": [{
            "source": "metis://labors/files/lion-stats.txt",
            "dest": "metis://labors/magma/monster-Nemean Lion-stats.txt"
          }]
        }))

      Timecop.return
    end

    it 'does not link a file from metis for an invalid update' do
      Timecop.freeze(DateTime.new(500))
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')
      update(
        monster: {
          'Nemean Lion' => {
            species: 'Lion',
            stats: {
              path: 'metis://labors/files/lion-stats.txt',
              original_filename: 'original-file.txt'
            }
          }
        }
      )

      # the record is unchanged
      lion.refresh
      expect(lion.stats).to be_nil
      expect(lion.species).to eq('lion')
      expect(last_response.status).to eq(422)

      # The metis endpoint was NOT called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
        with(query: hash_including({
          "X-Etna-Headers": "revisions"
        }))

      Timecop.return
    end
  end

  context 'image attributes' do
    it 'fails the update when the bulk copy request fails' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      # May be overkill ... but making sure each of the anticipated
      #   exceptions from Metis bulk_copy results in a failed Magma update.
      bad_request_statuses = [400, 403, 404, 422, 500]
      req_counter = 1
      bad_request_statuses.each do |status|
        stub_request(:post, /https:\/\/metis.test\/labors\/files\/copy/).
          to_return(status: status, body: '{}')

        update(
          monster: {
            'Nemean Lion' => {
              selfie: {
                path: 'metis://labors/files/lion-stats.txt'
              }
            }
          }
        )
        lion.refresh
        expect(lion.selfie).to eq nil  # Did not change from the create state
        expect(last_response.status).to eq(422)

        expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
          with(query: hash_including({
            "X-Etna-Headers": "revisions"
          })).times(req_counter)

        req_counter += 1
      end

      Timecop.return
    end

    it 'marks an image as blank' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      update(
        monster: {
          'Nemean Lion' => {
            selfie: {
              path: '::blank'
            }
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.selfie.to_json).to eq({
        location: "::blank",
        filename: "::blank",
        original_filename: "::blank"}.to_json)

      expect(last_response.status).to eq(200)

      # and we do not get an upload url for Metis
      expect(json_document(:monster, 'Nemean Lion')[:selfie][:path]).to eq('::blank')
      expect(json_document(:monster, 'Nemean Lion')[:selfie][:url]).to be_nil

      # Make sure the Metis copy endpoint was not called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'removes an image reference' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion', selfie: '{"location": "metis://labors/Nemean Lion/headshot.png", "filename": "", "original_filename": ""}')

      update(
        monster: {
          'Nemean Lion' => {
            selfie: {
              path: nil
            }
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.selfie.to_json).to eq({
        location: nil,
        filename: nil,
        original_filename: nil
      }.to_json)

      expect(last_response.status).to eq(200)

      # and we do not get an upload url for Metis
      expect(json_document(:monster, 'Nemean Lion')[:selfie]).to be_nil

      # Make sure the Metis copy endpoint was not called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'removes an image reference using ::blank' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion', selfie: '{"location": "metis://labors/Nemean Lion/headshot.png", "filename": "", "original_filename": ""}')

      update(
        monster: {
          'Nemean Lion' => {
            selfie: {
              path: '::blank'
            }
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.selfie.to_json).to eq({
        location: '::blank',
        filename: '::blank',
        original_filename: '::blank'
      }.to_json)

      expect(last_response.status).to eq(200)

      # and we do not get an upload url for Metis
      expect(json_document(:monster, 'Nemean Lion')[:selfie]).to eq({
        path: '::blank'})

      # Make sure the Metis copy endpoint was not called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'returns a temporary Metis path when using ::temp' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      update(
        monster: {
          'Nemean Lion' => {
            selfie: {
              path: '::temp'
            }
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.selfie).to eq(nil)
      expect(last_response.status).to eq(200)

      # but we do get an upload url for Metis
      upload_url = json_document(:monster, 'Nemean Lion')[:selfie][:path]
      expect(upload_url.
        start_with?('https://metis.test/labors/upload/magma/tmp-')).to eq(true)
      expect(upload_url.
        include?('X-Etna-Signature=')).to eq(true)

      # Make sure the Metis copy endpoint was not called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'links an image from metis' do
      Timecop.freeze(DateTime.new(500))
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')
      update(
        monster: {
          'Nemean Lion' => {
            selfie: {
              path: 'metis://labors/files/lion.jpg',
              original_filename: 'closeup.jpg'
            }
          }
        }
      )

      lion.refresh
      expect(lion.selfie.to_json).to eq({
        location: 'metis://labors/files/lion.jpg',
        filename: 'monster-Nemean Lion-selfie.jpg',
        original_filename: 'closeup.jpg'}.to_json)

      expect(last_response.status).to eq(200)

      # but we do get an download url for Metis
      uri = URI.parse(json_document(:monster, 'Nemean Lion')[:selfie][:url])
      params = Rack::Utils.parse_nested_query(uri.query)
      expect(uri.host).to eq(Magma.instance.config(:storage)[:host])
      expect(uri.path).to eq('/labors/download/magma/monster-Nemean%20Lion-selfie.jpg')
      expect(params['X-Etna-Id']).to eq('magma')
      expect(params['X-Etna-Expiration']).to eq((Time.now + Magma.instance.config(:storage)[:download_expiration]).iso8601)

      expect(json_document(:monster, 'Nemean Lion')[:selfie].key?(:path)).to eq (true)
      expect(json_document(:monster, 'Nemean Lion')[:selfie].key?(:original_filename)).to eq (true)

      # Make sure the Metis copy endpoint was called
      expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
        with(query: hash_including({
          "X-Etna-Headers": "revisions"
        }), body: hash_including({
          "revisions": [{
            "source": "metis://labors/files/lion.jpg",
            "dest": "metis://labors/magma/monster-Nemean Lion-selfie.jpg"
          }]
        }))

      Timecop.return
    end
  end

  context 'file collection attributes' do
    it 'fails the update when the bulk copy request fails' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      # May be overkill ... but making sure each of the anticipated
      #   exceptions from Metis bulk_copy results in a failed Magma update.
      bad_request_statuses = [400, 403, 404, 422, 500]
      req_counter = 1
      bad_request_statuses.each do |status|
        stub_request(:post, /https:\/\/metis.test\/labors\/files\/copy/).
          to_return(status: status, body: '{}')

        update(
          monster: {
            'Nemean Lion' => {
              certificates: [{
                path: 'metis://labors/files/lion-stats.txt'
              }]
            }
          }
        )
        lion.refresh
        expect(lion.certificates).to eq nil  # Did not change from the create state
        expect(last_response.status).to eq(422)

        expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
          with(query: hash_including({
            "X-Etna-Headers": "revisions"
          })).times(req_counter)
        req_counter += 1
      end

      Timecop.return
    end

    it 'removes a set of existing files' do
      lion = create(
        :monster,
        name: 'Nemean Lion',
        species: 'lion',
        certificates: [{
          filename: 'monster-Nemean Lion-certificates-0.txt'
        }, {
          filename: 'monster-Nemean Lion-certificates-1.txt'
        }].to_json)

      update(
        monster: {
          'Nemean Lion' => {
            certificates: []
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.certificates).to eq([])

      expect(last_response.status).to eq(200)

      # Make sure the Metis copy endpoint was not called
      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'removes a file reference from an existing set' do
      lion = create(
        :monster,
        name: 'Nemean Lion',
        species: 'lion',
        certificates: [{
          filename: 'monster-Nemean Lion-certificates-0.txt'
        }, {
          filename: 'monster-Nemean Lion-certificates-1.txt'
        }].to_json)

      update(
        monster: {
          'Nemean Lion' => {
            certificates: [
              {
                path: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt'
              }
            ]
          }
        }
      )

      lion.refresh
      expect(lion.certificates.to_json).to eq([{
        location: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt',
        filename: 'monster-Nemean Lion-certificates-0.txt',
        original_filename: nil
      }].to_json)

      expect(last_response.status).to eq(200)

      # and we do get a download url for Metis
      expect(json_document(:monster, 'Nemean Lion')[:certificates].length).to eq(1)
      url = json_document(:monster, 'Nemean Lion')[:certificates].first[:url]
      expect(url.
        start_with?('https://metis.test/labors/download/magma/monster-Nemean%20Lion-certificates-0.txt')).to eq(true)
      expect(url.
        include?('X-Etna-Signature=')).to eq(true)

      # Make sure the Metis copy endpoint was called
      expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'rejects the update if revision missing :path' do
      original_certs = [{
        filename: 'monster-Nemean Lion-certificates-0.txt'
      }, {
        filename: 'monster-Nemean Lion-certificates-1.txt'
      }].to_json

      lion = create(
        :monster,
        name: 'Nemean Lion',
        species: 'lion',
        certificates: original_certs)

      update(
        monster: {
          'Nemean Lion' => {
            certificates: [{
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-0.txt'
            }, {
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt'
            }, {
              original_filename: 'CharmSchool.pdf'
            }]
          }
        }
      )

      expect(last_response.status).to eq(422)

      lion.refresh
      expect(lion.certificates.to_json).to eq original_certs  # Did not change from the create state

      expect(WebMock).not_to have_requested(:post, "https://metis.test/labors/files/copy").
        with(query: hash_including({
          "X-Etna-Headers": "revisions"
        }))
    end

    it 'can update even if existing file revisions not in ascending order' do
      original_certs = [{
        filename: 'monster-Nemean Lion-certificates-0.txt',
        original_filename: 'certificate-0.txt'
      }, {
        filename: 'monster-Nemean Lion-certificates-1.txt',
        original_filename: 'certificate-1.txt'
      }].to_json

      lion = create(
        :monster,
        name: 'Nemean Lion',
        species: 'lion',
        certificates: original_certs)

      update(
        monster: {
          'Nemean Lion' => {
            certificates: [{
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt',
              original_filename: 'certificate-1.txt'
            }, {
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-0.txt',
              original_filename: 'certificate-0.txt'
            }]
          }
        }
      )

      expect(last_response.status).to eq(200)

      lion.refresh
      expect(lion.certificates.to_json).to eq([{
        location: "metis://labors/magma/monster-Nemean Lion-certificates-1.txt",
        filename: 'monster-Nemean Lion-certificates-0.txt',
        original_filename: 'certificate-1.txt'
      }, {
        location: "metis://labors/magma/monster-Nemean Lion-certificates-0.txt",
        filename: 'monster-Nemean Lion-certificates-1.txt',
        original_filename: 'certificate-0.txt'
      }].to_json)

      expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
        with(query: hash_including({
          "X-Etna-Headers": "revisions"
        }))
    end

    it 'can update even if new files are not at the end of the array' do
      original_certs = [{
        filename: 'monster-Nemean Lion-certificates-0.txt'
      }, {
        filename: 'monster-Nemean Lion-certificates-1.txt'
      }].to_json

      lion = create(
        :monster,
        name: 'Nemean Lion',
        species: 'lion',
        certificates: original_certs)

      update(
        monster: {
          'Nemean Lion' => {
            certificates: [{
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-0.txt',
              original_filename: 'certificate-0.txt'
            }, {
              path: 'metis://labors/files/CharmSchool.pdf',
              original_filename: 'CharmSchool.pdf'
            }, {
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt',
              original_filename: 'certificate-1.txt'
            }]
          }
        }
      )

      expect(last_response.status).to eq(200)

      lion.refresh

      expect(lion.certificates.to_json).to eq([{
        location: 'metis://labors/magma/monster-Nemean Lion-certificates-0.txt',
        filename: 'monster-Nemean Lion-certificates-0.txt',
        original_filename: 'certificate-0.txt'
      }, {
        location: 'metis://labors/files/CharmSchool.pdf',
        filename: 'monster-Nemean Lion-certificates-1.pdf',
        original_filename: 'CharmSchool.pdf'
      }, {
        location: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt',
        filename: 'monster-Nemean Lion-certificates-2.txt',
        original_filename: 'certificate-1.txt'
      }].to_json)

      expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
        with(query: hash_including({
          "X-Etna-Headers": "revisions"
        }))
    end

    it 'returns a temporary Metis path when using ::temp' do
      original_certs = [{
        filename: 'monster-Nemean Lion-certificates-0.txt'
      }, {
        filename: 'monster-Nemean Lion-certificates-1.txt'
      }].to_json

      lion = create(
        :monster,
        name: 'Nemean Lion',
        species: 'lion',
        certificates: original_certs)

      update(
        monster: {
          'Nemean Lion' => {
            certificates: [{
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-0.txt'
            }, {
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt'
            }, {
              path: '::temp'
            }, {
              path: '::temp'
            }]
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.certificates.to_json).to eq([{
        location: 'metis://labors/magma/monster-Nemean Lion-certificates-0.txt',
        filename: 'monster-Nemean Lion-certificates-0.txt',
        original_filename: nil
      }, {
        location: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt',
        filename: 'monster-Nemean Lion-certificates-1.txt',
        original_filename: nil
      }].to_json)

      expect(last_response.status).to eq(200)

      # but we do get an upload url for Metis, for the temporary paths!
      expect(json_document(:monster, 'Nemean Lion')[:certificates].length).to eq(4)
      urls = []
      urls << json_document(:monster, 'Nemean Lion')[:certificates][2][:path]
      urls << json_document(:monster, 'Nemean Lion')[:certificates].last[:path]

      expect(urls.all? { |u|
          u.start_with?('https://metis.test/labors/upload/magma/tmp-')
        }).to eq(true)
      expect(urls.all? { |u|
          u.include?('X-Etna-Signature=')
        }).to eq(true)

      # Make sure the Metis copy endpoint was called (for the original files)
      expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
      with(query: hash_including({
        "X-Etna-Headers": "revisions"
      }))
    end

    it 'can update even if temporary Metis paths are not at the end' do
      original_certs = [{
        filename: 'monster-Nemean Lion-certificates-0.txt'
      }, {
        filename: 'monster-Nemean Lion-certificates-1.txt'
      }].to_json

      lion = create(
        :monster,
        name: 'Nemean Lion',
        species: 'lion',
        certificates: original_certs)

      update(
        monster: {
          'Nemean Lion' => {
            certificates: [{
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-0.txt',
              original_filename: 'certificate-0.txt'
            }, {
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt',
              original_filename: 'certificate-1.txt'
            }, {
              path: '::temp'
            }, {
              path: 'metis://labors/files/new-pirate-certificate.txt',
              original_filename: 'new-pirate-certificate.txt'
            }, {
              path: '::temp'
            }]
          }
        }
      )

      expect(last_response.status).to eq(200)

      lion.refresh
      expect(lion.certificates.to_json).to eq([{
        location: 'metis://labors/magma/monster-Nemean Lion-certificates-0.txt',
        filename: 'monster-Nemean Lion-certificates-0.txt',
        original_filename: 'certificate-0.txt'
      }, {
        location: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt',
        filename: 'monster-Nemean Lion-certificates-1.txt',
        original_filename: 'certificate-1.txt'
      }, {
        location: 'metis://labors/files/new-pirate-certificate.txt',
        filename: 'monster-Nemean Lion-certificates-3.txt',
        original_filename: 'new-pirate-certificate.txt'
      }].to_json)

      expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
        with(query: hash_including({
          "X-Etna-Headers": "revisions"
        }))
    end

    it 'links a new file from metis' do
      Timecop.freeze(DateTime.new(500))
      original_certs = [{
        filename: 'monster-Nemean Lion-certificates-0.txt'
      }, {
        filename: 'monster-Nemean Lion-certificates-1.txt'
      }].to_json

      lion = create(
        :monster,
        name: 'Nemean Lion',
        species: 'lion',
        certificates: original_certs)

      update(
        monster: {
          'Nemean Lion' => {
            certificates: [{
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-0.txt'
            }, {
              path: 'metis://labors/magma/monster-Nemean Lion-certificates-1.txt'
            }, {
              path: 'metis://labors/files/CharmSchool.pdf'
            }]
          }
        }
      )

      expect(last_response.status).to eq(200)

      lion.refresh
      expect(lion.certificates.to_json).not_to eq original_certs

      # and we do get an download url for Metis
      uri = URI.parse(json_document(:monster, 'Nemean Lion')[:certificates].last[:url])
      params = Rack::Utils.parse_nested_query(uri.query)
      expect(uri.host).to eq(Magma.instance.config(:storage)[:host])
      expect(uri.path).to eq('/labors/download/magma/monster-Nemean%20Lion-certificates-2.pdf')
      expect(params['X-Etna-Id']).to eq('magma')
      expect(params['X-Etna-Expiration']).to eq((Time.now + Magma.instance.config(:storage)[:download_expiration]).iso8601)

      expect(json_document(:monster, 'Nemean Lion')[:certificates].last.key?(:path)).to eq (true)
      expect(json_document(:monster, 'Nemean Lion')[:certificates].last.key?(:original_filename)).to eq (true)

      # Make sure the Metis copy endpoint was called
      expect(WebMock).to have_requested(:post, "https://metis.test/labors/files/copy").
        with(query: hash_including({
          "X-Etna-Headers": "revisions"
        }), body: hash_including({
          "revisions": [{
            "source":"metis://labors/magma/monster-Nemean Lion-certificates-0.txt",
            "dest":"metis://labors/magma/monster-Nemean Lion-certificates-0.txt"
          }, {
            "source":"metis://labors/magma/monster-Nemean Lion-certificates-1.txt",
            "dest":"metis://labors/magma/monster-Nemean Lion-certificates-1.txt"
          }, {
            "source": "metis://labors/files/CharmSchool.pdf",
            "dest": "metis://labors/magma/monster-Nemean Lion-certificates-2.pdf"
          }]
        }))

      Timecop.return
    end
  end

  it 'updates a matrix' do
    labor = create(:labor, name: 'Nemean Lion', project: @project)
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
    labor = create(:labor, name: 'Nemean Lion', project: @project)
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

  context 'validation' do
    def validation_stubs
      @validation_stubs ||= {}
    end

    before(:each) do
      stub_validation(Labors::Monster, :name, {
        type: "Regexp", value: /^[A-Z][a-z]+ [A-Z][a-z]+$/
      })
    end

    after(:each) do
      remove_validation_stubs
    end

    it 'fails on validation checks for attributes' do
      # The actual validation is defined in spec/fixtures/labors_model_attributes.yml
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

    it 'fails on validation checks for the record name, on create' do
      update(
        monster: {
          'nemean lion': {
            species: 'lion'
          }
        }
      )

      expect(last_response.status).to eq(422)
    end

    it 'allows you to rename an invalid record' do
      lion = create(:monster, name: 'nemean lion')
      update(
        monster: {
          'nemean lion': {
            name: 'Nemean Lion'
          }
        }
      )

      lion.refresh
      expect(last_response.status).to eq(200)
      expect(lion.name).to eq('Nemean Lion')
    end

    it 'can update other attributes for an invalid record' do
      lion = create(:monster, name: 'nemean lion')
      expect(lion.species).to eq(nil)
      update(
        monster: {
          'nemean lion': {
            species: 'lion'
          }
        }
      )

      lion.refresh
      expect(last_response.status).to eq(200)
      expect(lion.species).to eq('lion')
    end
  end

  context 'projects' do
    it 'prevents additional project records from being created' do
      update(project: { "The Ten Labors of Hercules": { } })

      expect(Labors::Project.count).to eq(1)
      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Project name must match 'The Twelve Labors of Hercules'"])
    end

    it 'prevents additional project parents from being created' do
      update(labor: { "The Nemean Lion": { project: "The Ten Labors of Hercules" } })

      expect(Labors::Project.count).to eq(1)
      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Project name must match 'The Twelve Labors of Hercules'"])
    end

    it 'allows a root record to be created if there is none' do
      Labors::Project.first.delete

      update(project: { "The Ten Labors of Hercules": { } })

      expect(last_response.status).to eq(200)
      expect(Labors::Project.count).to eq(1)
    end
  end

  context 'restriction' do
    it 'prevents updates to a restricted record by a restricted user' do
      orig_name = 'Outis Koutsonadis'
      new_name  = 'Outis Koutsomadis'
      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, :lion, labor: labor)
      restricted_victim = create(:victim, name: orig_name, restricted: true, monster: lion)

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
      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Cannot revise restricted victim '#{orig_name}'"])

      restricted_victim.refresh
      expect(restricted_victim.name).to eq(orig_name)
    end

    it 'prevents updates to the child of a restricted record by a restricted user' do
      orig_name = 'Outis Koutsonadis'
      new_name  = 'Outis Koutsomadis'
      labor = create(:labor, :lion, project: @project)
      lion = create(:monster, name: 'Nemean Lion', species: 'lion', restricted: true, labor: labor)
      restricted_victim = create(:victim, monster: lion, name: orig_name)

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
      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Cannot revise restricted victim '#{orig_name}'"])

      restricted_victim.refresh
      expect(restricted_victim.name).to eq(orig_name)
    end

    it 'allows updates to a restricted record by a privileged user' do
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
        :privileged_editor
      )
      expect(last_response.status).to eq(200)
      expect(json_document(:victim,new_name)).to eq(name: new_name)

      expect(Labors::Victim.count).to eq(1)
      restricted_victim.refresh
      expect(restricted_victim.name).to eq(new_name)
    end

    it 'allows updates to a child of a restricted record by a privileged user' do
      orig_name = 'Outis Koutsonadis'
      new_name  = 'Outis Koutsomadis'
      lion = create(:monster, name: 'Nemean Lion', species: 'lion', restricted: true)
      restricted_victim = create(:victim, monster: lion, name: orig_name)

      update(
        {
          victim: {
            orig_name => {
              name: new_name
            }
          }
        },
        :privileged_editor
      )
      expect(last_response.status).to eq(200)
      expect(json_document(:victim,new_name)).to eq(name: new_name)

      expect(Labors::Victim.count).to eq(1)
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
        :editor
      )
      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Cannot revise restricted attribute :country on victim 'Outis Koutsonadis'"])

      victim.refresh
      expect(victim.country).to eq('nemea')
    end

    it 'prevents updates to the restricted column by a restricted user' do
      victim = create(:victim, name: 'Outis Koutsonadis', country: 'nemea')

      update(
          {
              victim: {
                  'Outis Koutsonadis': {
                      restricted: false
                  }
              }
          },
          :editor
      )
      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Cannot revise restricted attribute :restricted on victim 'Outis Koutsonadis'"])

      expect { victim.refresh }.not_to change { victim.restricted }
    end

    it 'allows updates to a restricted attribute by a privileged user' do
      victim = create(:victim, name: 'Outis Koutsonadis', country: 'nemea')

      update(
        {
          victim: {
            'Outis Koutsonadis': {
              country: 'thrace'
            }
          }
        },
        :privileged_editor
      )
      expect(last_response.status).to eq(200)
      expect(json_document(:victim,'Outis Koutsonadis')).to include(country: 'thrace')

      victim.refresh
      expect(victim.country).to eq('thrace')
    end

    it 'allows updates to the restricted column by a privileged user' do
      victim = create(:victim, name: 'Outis Koutsonadis', country: 'nemea')

      update(
          {
              victim: {
                  'Outis Koutsonadis': {
                      restricted: false
                  }
              }
          },
          :privileged_editor
      )
      expect(last_response.status).to eq(200)

      expect { victim.refresh }.to change { victim.restricted }.to(false)
    end
  end

  context 'shifted_date_time attributes' do
    before(:each) do
      stub_date_shift_data(@project)
      set_date_shift_root('monster', true)
      # Magma.instance.configure({:test => { :dateshift_salt => '123' } })
    end

    after(:each) do
      set_date_shift_root('monster', false)
      set_date_shift_root('victim', false)
    end

    it 'fails the update when no salt in config' do
      Magma.instance.configure({:test => { :dateshift_salt => '' } })
      
      expect(@john_doe.birthday).to eq(nil)

      update(
        victim: {
          @john_doe.name => {
            birthday: '2000-01-01'
          }
        }
      )

      require 'pry'
      binding.pry
      expect(last_response.status).to eq(422)
      @john_doe.refresh
      expect(@john_doe.birthday).to eq(nil)
    end

    context 'with tables' do
      it 'shifts date on update to existing row' do
        expect(true).to eq(false)
      end

      it 'shifts date on create of a new row, parent exists' do
        expect(true).to eq(false)
      end

      it 'shifts date when parent record created in same update' do
        expect(true).to eq(false)
      end

      it 'shifts dates when update contains shifted and not-shifted data' do

      end

      it 'throws exception if included in create of disconnected row' do
        expect(true).to eq(false)
      end

      it 'throws exception if included in create of connected row, but no date-shift root' do
        expect(true).to eq(false)
      end
    end

    context 'with non-table models' do
      it 'shifts date on create of a new record in the date-shift-root model' do
        set_date_shift_root('monster', false)
        set_date_shift_root('victim', true)

        update(
          victim: {
            "Unicorn" => {
              birthday: '2000-01-01'
            }
          }
        )
  
        expect(last_response.status).to eq(200)
        expect(json_body[:models][:victim][:documents][:Unicorn][:birthday]).not_to eq(DateTime.parse('2000-01-01').iso8601)
      end

      it 'shifts date on update of an existing record in the date-shift-root model' do
        set_date_shift_root('monster', false)
        set_date_shift_root('victim', true)
        expect(@john_doe[:birthday]).to eq(nil)

        update(
          victim: {
            @john_doe.name => {
              birthday: '2000-01-01'
            }
          }
        )
  
        expect(last_response.status).to eq(200)
        expect(
          json_body[:models][:victim][:documents][@john_doe.name.to_sym][:birthday]
        ).not_to eq(DateTime.parse('2000-01-01').iso8601)
        
        @john_doe.refresh
        expect(@john_doe[:birthday]).not_to eq(nil)
        expect(@john_doe[:birthday]).not_to eq("2000-01-01")
      end

      it 'shifts date on create of a new record, parent exists, not date-shift-root model' do
        update(
          victim: {
            "Unicorn" => {
              monster: @lion_monster.name,
              birthday: '2000-01-01'
            }
          }
        )
  
        expect(last_response.status).to eq(200)
        expect(json_body[:models][:victim][:documents][:Unicorn][:birthday]).not_to eq(DateTime.parse('2000-01-01').iso8601)
      end

      it 'shifts date on update of an existing record, parent exists, not date-shift-root model' do
        expect(@john_doe[:birthday]).to eq(nil)

        update(
          victim: {
            @john_doe.name => {
              birthday: '2000-01-01'
            }
          }
        )
  
        expect(last_response.status).to eq(200)
        expect(
          json_body[:models][:victim][:documents][@john_doe.name.to_sym][:birthday]
        ).not_to eq(DateTime.parse('2000-01-01').iso8601)
        
        @john_doe.refresh
        expect(@john_doe[:birthday]).not_to eq(nil)
        expect(@john_doe[:birthday]).not_to eq("2000-01-01")
      end

      it 'shifts date when parent record created in same update' do
        update(
          victim: {
            "Unicorn" => {
              monster: "Vampire",
              birthday: '2000-01-01'
            }
          },
          monster: {
            "Vampire" => {}
          }
        )
  
        expect(last_response.status).to eq(200)
        expect(json_body[:models][:victim][:documents][:Unicorn][:birthday]).not_to eq(DateTime.parse('2000-01-01').iso8601)
      end

      it 'shifts date with combination of created parents + existing parents' do
        set_date_shift_root("monster", false)
        set_date_shift_root("labor", true)

        update(
          victim: {
            Unicorn: {
              monster: "Vampire",
              birthday: '2000-01-01'
            }
          },
          monster: {
            Vampire: {
              name: "Vampire",
              labor: @hind.name
            }
          }
        )
  
        expect(last_response.status).to eq(200)
        expect(json_body[:models][:victim][:documents][:Unicorn][:birthday]).not_to eq(DateTime.parse('2000-01-01').iso8601)

        set_date_shift_root("labor", false) 
      end

      it 'shifts dates when update contains shifted and not-shifted data' do
        expect(@john_doe[:birthday]).to eq(nil)
        expect(@susan_doe[:weapon]).to eq(nil)

        update(
          victim: {
            @john_doe.name => {
              birthday: '2000-01-01'
            },
            @susan_doe.name => {
              weapon: "Bow and arrow"
            }
          }
        )
  
        expect(last_response.status).to eq(200)
        expect(
          json_body[:models][:victim][:documents][@john_doe.name.to_sym][:birthday]
        ).not_to eq(DateTime.parse('2000-01-01').iso8601)
        
        @john_doe.refresh
        expect(@john_doe[:birthday]).not_to eq(nil)
        expect(@john_doe[:birthday]).not_to eq("2000-01-01")

        @susan_doe.refresh
        expect(@susan_doe[:weapon]).to eq("Bow and arrow")
      end

      it 'shifts date for disconnected record if is in date_shift_root model' do
        set_date_shift_root('monster', false)
        set_date_shift_root('victim', true)

        expect(@john_doe[:birthday]).to eq(nil)

        update(
          victim: {
            @john_doe.name => {
              monster: nil,
              birthday: '2000-01-01'
            }
          }
        )
  
        expect(last_response.status).to eq(200)
        expect(json_body[:models][:victim][:documents][@john_doe.name.to_sym][:birthday]).not_to eq(DateTime.parse('2000-01-01').iso8601)

        @john_doe.refresh
        expect(@john_doe[:birthday]).not_to eq(nil)
        expect(@john_doe[:birthday]).not_to eq("2000-01-01")

        set_date_shift_root('victim', false)
      end

      it 'throws exception if disconnecting from date_shift_root during the update' do
        expect(@john_doe[:birthday]).to eq(nil)

        update(
          victim: {
            @john_doe.name => {
              monster: nil,
              birthday: '2000-01-01'
            }
          }
        )
  
        expect(last_response.status).to eq(422)

        @john_doe.refresh
        expect(@john_doe[:birthday]).to eq(nil)
      end

      it 'throws exception on update if disconnected from date_shift_root in database' do
        expect(@john_doe[:birthday]).to eq(nil)

        @john_doe.update(monster: nil)
        @john_doe.save

        update(
          victim: {
            @john_doe.name => {
              birthday: '2000-01-01'
            }
          }
        )
  
        expect(last_response.status).to eq(422)

        @john_doe.refresh
        expect(@john_doe[:birthday]).to eq(nil)
      end

      it 'throws exception if creating disconnected record that requires date-shifting' do
        expect(Labors::Victim.count).to eq(4)

        update(
          victim: {
            "Unicorn" => {
              birthday: '2000-01-01'
            }
          }
        )
  
        expect(last_response.status).to eq(422)
        expect(Labors::Victim.count).to eq(4)
      end

      it 'throws exception if creating connected record, but no date-shift root model set' do
        set_date_shift_root('monster', false)
        expect(Labors::Victim.count).to eq(4)

        update(
          victim: {
            "Unicorn" => {
              monster: @lion_monster.name,
              birthday: '2000-01-01'
            }
          }
        )
  
        expect(last_response.status).to eq(422)
        expect(Labors::Victim.count).to eq(4)
      end
    end
  end
end
