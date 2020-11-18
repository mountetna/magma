require 'securerandom'

describe Magma::AddProjectAction do
  let(:project_name) { "testproject#{SecureRandom.uuid.gsub('-', '')}" }
  let(:action_params) { {
    project_name: project_name,
    user: Etna::User.new({
      email: "outis@mountolympus.org",
      token: "fake"
    })
   } }

  describe "#perform" do
    def run_once
      action = Magma::AddProjectAction.new(
        project_name,
        action_params
      )
      action.validate
      expect(action.errors).to eql([])
      expect(action.validate).to eql(true)
      unless action.perform
        expect(action.errors).to eql([])
        raise "action.perform failed but there were no errors"
      end
      action
    end

    before(:each) do
      setup_metis_bucket_stubs(project_name)
    end

    it 'idempotently adds the project' do
      run_once
      expect(Magma.instance.get_model(project_name, :project)).to_not be_nil

      # Change the stub because Metis should complain the second time.
      route_payload = JSON.generate(
        {:error=>'Duplicate bucket.'}
      )
      stub_request(:post, /https:\/\/metis.test\/#{project_name}\/bucket\/create/).
        to_return(status: 422, body: route_payload, headers: {'Content-Type': 'application/json'})

      run_once
      expect(Magma.instance.get_model(project_name, :project)).to_not be_nil

      # Make sure the Metis create_bucket endpoint was called
      expect(WebMock).to have_requested(:post, /https:\/\/metis.test\/#{project_name}\/bucket\/create\/magma/).
      with(query: hash_including({
        "X-Etna-Headers": "owner,description,access"
      }), body: hash_including({
        "owner": "magma",
        "access": "administrator"
      })).times(2)
    end

    it 'captures an error on invalid project names' do
      [ "my\nmproject", ' my_project', 'my_project	' , '1x_project', 'pg_project', 'my_project_2'].each do |name|
        action = Magma::AddProjectAction.new(name, action_params)
        action.validate
        expect(action.errors.first[:message]).to eql("project_name must only consist of lowercase letters and numbers, and not start with a number.")
        expect(action.validate).to eql(false)
      end
    end

    it 'does not call Metis if no create_bucket route exists' do
      # Change the stub
      route_payload = JSON.generate([])
      stub_request(:options, 'https://metis.test').
        to_return(status: 200, body: route_payload, headers: {'Content-Type': 'application/json'})

      action = Magma::AddProjectAction.new(
        project_name,
        action_params
      )
      action.validate
      expect(action.errors).to eql([])
      expect(action.validate).to eql(true)
      action.perform
      expect(action.errors).to eql([{
        message: "No bucket_create route on the Metis storage host -- will not be able to link files for this",
        reason: nil,
        source: "setup_metis"}])

      expect(Magma.instance.get_model(project_name, :project)).to_not be_nil

      # Make sure the Metis create_bucket endpoint was NOT called
      expect(WebMock).not_to have_requested(:post, /https:\/\/metis.test\/#{project_name}\/bucket\/create\/magma/).
      with(query: hash_including({
        "X-Etna-Headers": "owner,description,access"
      }), body: hash_including({
        "owner": "magma",
        "access": "administrator"
      }))
    end

    # Does not work due to sequel caching, normally a restart is required to fully clear caches.
    xit 'would load projects that only exist in the db' do
      run_once

      Magma.instance.magma_projects.delete(project_name)

      Magma.instance.load_models
      Magma.instance.get_model(project_name, :magic_model).to_not be_nil
    end
  end
end
