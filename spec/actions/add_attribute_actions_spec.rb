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
      link_model_name: "species",
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
        expect(Labors::Monster.dataset.columns!).to include(attribute_name.to_sym)
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

    context "when the attribute already exists" do
      let(:attribute_name) { 'name' }

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq('Attribute already exists')
      end
    end
  end
end
