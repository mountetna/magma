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
    project = create(:project, name: 'The Two Labors of Hercules')

    Timecop.freeze(later)
    update(
      'project' => {
        'The Two Labors of Hercules' => {
          name: 'The Ten Labors of Hercules'
        }
      }
    )

    expect(last_response.status).to eq(200)
    expect(json_document(:project, 'The Ten Labors of Hercules')).to eq(name: 'The Ten Labors of Hercules')

    # the update happened
    expect(Labors::Project.count).to eq(1)
    project.refresh
    expect(project.name).to eq('The Ten Labors of Hercules')

    # we updated updated_at
    expect(project.updated_at).to be_within(0.001).of(later)
    Timecop.return
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
    it 'updates a parent attribute' do
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

      expect(last_response.status).to eq(200)
      expect(json_document(:monster,'Lernean Hydra')).to include(labor: 'The Lernean Hydra')

      monster.refresh
      hydra.refresh
      expect(monster.labor).to eq(hydra)
    end

    it 'orphans a record' do
      hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01')

      monster = create(:monster, name: 'Lernean Hydra', labor: hydra)
      update(
        monster: {
          'Lernean Hydra': {
            labor: nil
          }
        }
      )

      expect(last_response.status).to eq(200)
      expect(json_document(:monster,'Lernean Hydra')).to include(labor: nil)

      monster.refresh
      hydra.refresh
      expect(monster.labor).to eq(nil)
    end

    it 'updates a link attribute' do
      hydra = create(:labor, name: 'The Lernean Hydra', year: '0003-01-01')

      other_monster = create(:monster, name: 'Nemean Lion')
      monster = create(:monster, name: 'Lernean Hydra', labor: hydra, reference_monster: other_monster)

      update(
        monster: {
          'Lernean Hydra': {
            reference_monster: 'Cnidaria'
          }
        }
      )

      expect(last_response.status).to eq(200)
      expect(json_document(:monster,'Lernean Hydra')).to include(reference_monster: 'Cnidaria')

      # A new record is created
      expect(Labors::Monster.count).to eq(3)
      cnidaria = Labors::Monster.last
      expect(cnidaria.name).to eq('Cnidaria')

      # the link has been made
      monster.refresh
      expect(monster.reference_monster).to eq(cnidaria)
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

    context 'table attributes' do
      before(:each) do
        @apple_of_joy = { name: 'apple of joy', worth: 2000 }
        @apple_of_discord = { name: 'apple of discord', worth: 3000 }
      end

      it 'updates a table' do
        labor = create(:labor, name: 'The Golden Apples of the Hesperides')
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
        labor = create(:labor, name: 'The Golden Apples of the Hesperides')
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
        lion_labor = create(:labor, name: 'The Nemean Lion')
        hide = create(:prize, name: 'hide', labor: lion_labor)

        apple_labor = create(:labor, name: 'The Golden Apples of the Hesperides')
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
      req_counter = 0
      bad_request_statuses.each do |status|
        stub_request(:post, /https:\/\/metis.test\/labors\/files\/copy?/).
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
        req_counter += 1
        lion.refresh
        expect(lion.stats).to eq nil  # Did not change from the create state
        expect(last_response.status).to eq(422)
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

      # but we do get an upload url for Metis
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
        start_with?('https://metis.test/labors/upload/magma/tmp/')).to eq(true)
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
      req_counter = 0
      bad_request_statuses.each do |status|
        stub_request(:post, /https:\/\/metis.test\/labors\/files\/copy?/).
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
        req_counter += 1
        lion.refresh
        expect(lion.selfie).to eq nil  # Did not change from the create state
        expect(last_response.status).to eq(422)
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

      # but we do get an upload url for Metis
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
        start_with?('https://metis.test/labors/upload/magma/tmp/')).to eq(true)
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
end
