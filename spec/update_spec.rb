describe Magma::UpdateController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  def update(revisions)
    json_post(:update, {project_name: 'labors', revisions: revisions})
  end

  it 'can update content' do
    lion = create(:monster, name: 'Nemean Lion', species: 'hydra')
    update(
      'monster' => {
        'Nemean Lion' => {
          species: 'lion'
        }
      }
    )
    lion.refresh
    expect(lion.species).to eq('lion')
    json = json_body(last_response.body)
    expect(json[:models][:monster][:documents][:'Nemean Lion']).to eq(name: 'Nemean Lion', species: 'lion')
    expect(last_response.status).to eq(200)
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

    expect(Labors::Labor.count).to be(2)
    json = json_body(last_response.body)
    expect(json[:models][:project][:documents][:'The Two Labors of Hercules']).to eq(name: 'The Two Labors of Hercules', labor: [ 'Lernean Hydra', 'Nemean Lion' ])
    expect(last_response.status).to eq(200)
  end

  it 'fails on validation checks' do
    # The actual validation is defined in spec/labors/models/monster.rb,
    # not sure how to move it here
    lion = create(:monster, name: 'Nemean Lion', species: 'lion')
    post(
      '/update',
      {
        revisions: {
          'monster' => {
            'Nemean Lion' => {
              species: 'Lion'
            }
          }
        },
        project_name: 'labors'
      }.to_json,
      {
        'CONTENT_TYPE' => 'application/json'
      }
    )

    lion.refresh
    expect(last_response.status).to eq(422)
    expect(lion.species).to eq('lion')
  end
end
