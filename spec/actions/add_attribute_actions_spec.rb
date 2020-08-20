describe Magma::AddAttributeAction do
  let(:project_name) { 'labors' }
  let(:action_params) do
    {
      action_name: "add_attribute",
      model_name: model_name,
      attribute_name: attribute_name,
      type: "string",
      description: "description",
      display_name: "name",
      format_hint: "incoming format hint",
      hidden: true,
      index: false,
      read_only: true,
      restricted: false,
      unique: true,
      validation: {"type": "Regexp", "value": "^[a-z\\s]+$"}
    }
  end

  let(:action) { Magma::AddAttributeAction.new(project_name, action_params) }
  let(:model_name) { "monster" }
  let(:attribute_name) { "number_of_claws" }

  describe '#perform' do
    context "when it succeeds" do
      after do
        # Clear out new test attributes that are cached in memory
        Labors::Monster.attributes.delete(attribute_name.to_sym)
      end

      it 'adds a new attribute and returns no errors' do
        expect(action.perform).to eq(true)
        expect(action.errors).to be_empty
        expect(Labors::Monster.attributes[attribute_name.to_sym].display_name).to eq("name")
      end
    end

    context 'when it fails' do
      let(:project_name) { nil }

      it "captures the error and doesn't add the attribute" do
        expect(action.perform).to eq(false)
        expect(action.errors).not_to be_empty
        expect(Labors::Monster.attributes[attribute_name.to_sym]).to be_nil
      end
    end
  end

  describe '#validate' do
    context "when all required fields are present and valid" do
      it "returns true and doesn't record any errors" do
        expect(action.validate).to eq(true)
        expect(action.errors).to be_empty
      end
    end

    context "when the model doesn't exist" do
      let(:model_name) { 'super_duper' }

      it 'captures a model error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Model does not exist")
      end
    end

    context "when setting the restricted property" do
      before(:each) { action_params[:restricted] = true }

      it 'succeeds' do
        expect(action.validate).to eq(true)
      end

      context "on an attribute named restricted" do
        let(:attribute_name) { 'restricted' }

        it 'fails' do
          expect(action.validate).to eq(false)
          expect(action.errors.last[:message]).to eq("restricted column may not, itself, be restricted")
        end
      end
    end

    context "when the attribute already exists" do
      let(:attribute_name) { 'name' }

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("attribute_name already exists on Labors::Monster")
      end
    end

    context "when attribute_name is not snake case" do
      let(:attribute_name) { 'firstName' }

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("attribute_name must be snake_case")
      end
    end

    context "when adding a link attribute with a link_model_name that doesn't exist" do
      let(:action_params) do
        {
          action_name: "add_attribute",
          model_name: model_name,
          attribute_name: attribute_name,
          type: "link",
          link_model_name: "houdini",
        }
      end

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("link_model_name doesn't match an existing model")
      end
    end

    context "when adding a link attribute with an attribute_name that doesn't exist" do
      let(:action_params) do
        {
          action_name: "add_attribute",
          model_name: model_name,
          attribute_name: "houdini",
          type: "parent"
        }
      end

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("attribute_name doesn't match an existing model")
      end
    end

    context "when an option doesn't exist" do
      let(:action_params) do
        {
          action_name: "add_attribute",
          model_name: model_name,
          attribute_name: attribute_name,
          type: "string",
          foo: "bar"
        }
      end

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Attribute does not implement foo")
      end
    end
  end
end
