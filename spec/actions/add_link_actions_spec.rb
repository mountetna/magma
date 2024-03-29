describe Magma::AddLinkAction do
  let(:user) {Etna::User.new({
    email: "outis@mountolympus.org",
    token: "fake"
  })}
  let(:action_params) do
    {
      action_name: "add_link",
      links: [
          { model_name: 'model_a', attribute_name: 'link_to_b', type: 'link' },
          { model_name: 'model_b', attribute_name: 'link_to_a', type: 'child' },
      ]
    }
  end
  let(:project_name) { "add_link_test_project" }
  let(:action) { Magma::AddLinkAction.new(project_name, action_params) }

  before(:each) do
    setup_metis_bucket_stubs(project_name)
    Magma.instance.magma_projects.delete(project_name.to_sym)
    Object.class_eval { remove_const(:AddLinkTestProject)  if Object.const_defined?(:AddLinkTestProject) }
    expect(Magma::AddProjectAction.new(project_name, user: user).perform).to be_truthy
    Etna::Clients::Magma::AddAttributeAction
    ['model_a', 'model_b'].each do |model_name|
      expect(Magma::AddModelAction.new(
        project_name,
        {
          model_name: model_name,
          identifier: 'name',
          parent_model_name: 'project',
          parent_link_type: 'collection'
        }).perform).to be_truthy
    end
    AddLinkTestProject::ModelA.set_primary_key(:id)
    AddLinkTestProject::ModelB.set_primary_key(:id)
  end

  describe '#perform' do
    context "for child link" do
      it 'adds attributes and returns no errors' do
        unless action.perform
          expect(action.errors).to be_empty
        end
        expect(action.errors).to be_empty

        expect(model_a = Magma.instance.get_model(project_name, 'model_a')).to_not be_nil
        expect(model_a.attributes).to include(:link_to_b)
        expect(model_a.attributes[:link_to_b]).to be_a(Magma::LinkAttribute)

        expect(model_b = Magma.instance.get_model(project_name, 'model_b')).to_not be_nil
        expect(model_b.attributes).to include(:link_to_a)
        expect(model_b.attributes[:link_to_a]).to be_a(Magma::ChildAttribute)
      end
    end

    context "for a link and a collection" do
      before(:each) do
        action_params[:links][1][:type] = 'collection'
      end

      it 'adds a new link attribute and returns no errors' do
        unless action.perform
          expect(action.errors).to be_empty
        end
        expect(action.errors).to be_empty

        expect(model_a = Magma.instance.get_model(project_name, 'model_a')).to_not be_nil
        expect(model_a.attributes).to include(:link_to_b)
        expect(model_a.attributes[:link_to_b]).to be_a(Magma::LinkAttribute)

        expect(model_b = Magma.instance.get_model(project_name, 'model_b')).to_not be_nil
        expect(model_b.attributes).to include(:link_to_a)
        expect(model_b.attributes[:link_to_a]).to be_a(Magma::CollectionAttribute)
      end

      context "within the same model" do
        before(:each) do
          action_params[:links][1][:type] = 'collection'
          action_params[:links][0][:attribute_name] = 'umbrella_record'
          action_params[:links][1][:attribute_name] = 'associated_records'
          action_params[:links][1][:model_name] = action_params[:links][0][:model_name]
        end

        it 'adds a new link attribute and returns no errors' do
          unless action.perform
            expect(action.errors).to be_empty
          end
          expect(action.errors).to be_empty

          expect(model_a = Magma.instance.get_model(project_name, 'model_a')).to_not be_nil
          expect(model_a.attributes).to include(:umbrella_record)
          expect(model_a.attributes[:umbrella_record]).to be_a(Magma::LinkAttribute)

          expect(model_a.attributes).to include(:associated_records)
          expect(model_a.attributes[:associated_records]).to be_a(Magma::CollectionAttribute)
        end
      end
    end
  end

  describe '#validate' do
    context "when one of models doesn't exist" do
      before(:each) do
        action_params[:links][0][:model_name] = 'thingthingthing'
      end

      it 'captures a model error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Model does not exist")
      end
    end


    context "when adding a mutual collection" do
      before(:each) do
        action_params[:links][0][:type] = 'collection'
        action_params[:links][1][:type] = 'collection'
      end

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("links must include at least one link type")
      end
    end

    context "when missing the links parameter" do
      before(:each) do
        action_params[:links] = nil
      end

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("links must be an array")
      end
    end

    context "when the types are invalid" do
      before(:each) do
        action_params[:links][1][:type] = 'sauce'
      end

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("links must include at least one collection/child type")
      end
    end

    context "when missing a link type" do
      before(:each) do
        action_params[:links][0][:type] = 'sauce'
      end

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("links must include at least one link type")
      end
    end

    context "when the attribute already exists" do
      before(:each) do
        action_params[:links][0][:attribute_name] = 'name'
      end

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("attribute_name already exists on AddLinkTestProject::ModelA")
      end
    end
  end
end
