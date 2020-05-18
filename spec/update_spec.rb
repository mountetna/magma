require 'json'
require 'pry'

describe UpdateController do
  include Rack::Test::Methods

  def app
    OUTER_APP
  end

  before(:each) do
    route_payload = JSON.generate([
      {:method=>"POST", :route=>"/:project_name/file/copy/:bucket_name/:file_path", :name=>"file_copy", :params=>["project_name", "bucket_name", "file_path"]}
    ])
    stub_request(:options, 'https://metis.test').
    to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})

    route_payload = JSON.generate([
      {:success=>true}
    ])
    stub_request(:post, "https://metis.test/labors/file/copy/files/lion-stats.txt").
    to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})
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
    expect(Labors::Project.count).to eq(1)
    project.refresh
    expect(project.name).to eq('The Ten Labors of Hercules')
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
    expect(entry.lore.to_hash).to eq(new_lore)

    expect(last_response.status).to eq(200)
    expect(json_document(:codex, entry.id.to_s)).to eq(lore: new_lore.symbolize_keys)

    # Make sure the Metis copy endpoint was not called
    assert_not_requested(:post, "/metis.test\/labors\/file\/copy/")

  end

  context 'file attributes' do
    it 'fails the update when the link request fails' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      # May be overkill ... but making sure each of the anticipated
      #   exceptions from Metis copy results in a failed Magma update.
      bad_request_statuses = [400, 404, 403, 500]
      req_counter = 0
      bad_request_statuses.each do |status|
        stub_request(:post, "https://metis.test/labors/file/copy/files/lion-stats.txt").
        to_return(status: status)

        update(
          monster: {
            'Nemean Lion' => {
              stats: 'metis://labors/files/lion-stats.txt'
            }
          }
        )
        req_counter += 1
        lion.refresh
        expect(lion.stats).to eq nil  # Did not change from the create state
        expect(last_response.status).to eq(status)

        # Make sure the Metis copy endpoint was called
        assert_requested(:post, "https://metis.test/labors/file/copy/files/lion-stats.txt",
          times: req_counter) do |req|
            (req.body.include? 'new_bucket_name') &&
            (req.body.include? 'new_file_path') &&
            (req.body.include? 'X-Etna-Signature')
          end
      end

      Timecop.return
    end

    it 'marks a file as blank' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      update(
        monster: {
          'Nemean Lion' => {
            stats: '::blank'
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.stats).to eq '::blank'

      expect(last_response.status).to eq(200)

      # but we do get an upload url for Metis
      expect(json_document(:monster, 'Nemean Lion')[:stats][:path]).to eq('::blank')
      expect(json_document(:monster, 'Nemean Lion')[:stats][:url]).to be_nil

      # Make sure the Metis copy endpoint was not called
      assert_not_requested(:post, "/metis.test\/labors\/file\/copy/")
    end

    it 'removes a file reference' do
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')

      update(
        monster: {
          'Nemean Lion' => {
            stats: nil
          }
        }
      )

      # the field is updated
      lion.refresh
      expect(lion.stats).to eq nil

      expect(last_response.status).to eq(200)

      # but we do get an upload url for Metis
      expect(json_document(:monster, 'Nemean Lion')[:stats]).to be_nil

      # Make sure the Metis copy endpoint was not called
      assert_not_requested(:post, "/metis.test\/labors\/file\/copy/")
    end

    it 'links a file from metis' do
      Timecop.freeze(DateTime.new(500))
      lion = create(:monster, name: 'Nemean Lion', species: 'lion')
      update(
        monster: {
          'Nemean Lion' => {
            stats: 'metis://labors/files/lion-stats.txt'
          }
        }
      )

      lion.refresh
      expect(lion.stats).to eq 'monster-Nemean Lion-stats.txt'

      expect(last_response.status).to eq(200)

      # but we do get an upload url for Metis
      uri = URI.parse(json_document(:monster, 'Nemean Lion')[:stats][:url])
      params = Rack::Utils.parse_nested_query(uri.query)
      expect(uri.host).to eq(Magma.instance.config(:storage)[:host])
      expect(uri.path).to eq('/labors/download/magma/monster-Nemean%20Lion-stats.txt')
      expect(params['X-Etna-Id']).to eq('magma')
      expect(params['X-Etna-Expiration']).to eq((Time.now + Magma.instance.config(:storage)[:download_expiration]).iso8601)

      # Make sure the Metis copy endpoint was called
      assert_requested(:post, "https://metis.test/labors/file/copy/files/lion-stats.txt",
        times: 1) do |req|
          (req.body.include? 'new_bucket_name') &&
          (req.body.include? 'new_file_path') &&
          (req.body.include? 'X-Etna-Signature')
        end

      Timecop.return
    end
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

    # we have created some new records
    expect(Labors::Labor.count).to be(2)
    expect(Labors::Labor.select_map(:created_at)).to all( be_a(Time) )
    expect(Labors::Labor.select_map(:updated_at)).to all( be_a(Time) )

    # the labors are linked to the project
    project.refresh
    expect(project.labor.count).to eq(2)

    # the updated record is returned
    expect(last_response.status).to eq(200)
    expect(json_document(:project, 'The Two Labors of Hercules')[:labor]).to match_array([ 'Lernean Hydra', 'Nemean Lion' ])
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
        :editor
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
        :restricted_editor
      )
      expect(last_response.status).to eq(422)
      expect(json_body[:errors]).to eq(["Cannot revise restricted attribute :country on victim 'Outis Koutsonadis'"])

      victim.refresh
      expect(victim.country).to eq('nemea')
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
        :editor
      )
      expect(last_response.status).to eq(200)
      expect(json_document(:victim,'Outis Koutsonadis')).to include(country: 'thrace')

      victim.refresh
      expect(victim.country).to eq('thrace')
    end
  end
end
