require 'securerandom'

describe Magma::AddProjectAction do
  let(:project_name) { "test_project_#{SecureRandom.uuid.gsub('-', '_')}" }
  let(:action_params) { {
    project_name: project_name
   } }

  describe "#perform" do
    def run_once
      action = Magma::AddProjectAction.new(project_name, action_params)
      action.validate
      expect(action.errors).to eql([])
      expect(action.validate).to eql(true)
      unless action.perform
        expect(action.errors).to eql([])
        raise "action.perform failed but there were no errors"
      end
      action
    end

    it 'idempotently adds the project' do
      run_once
      expect(Magma.instance.get_model(project_name, :project)).to_not be_nil

      run_once
      expect(Magma.instance.get_model(project_name, :project)).to_not be_nil
    end

    it 'captures an error on invalid project names' do
      [ "my\nmproject", ' my_project', 'my_project	' , '1x_project', 'pg_project'].each do |name|
        action = Magma::AddProjectAction.new(name, action_params)
        action.validate
        expect(action.errors.first[:message]).to eql("project_name must be snake_case with no spaces")
        expect(action.validate).to eql(false)
      end
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
