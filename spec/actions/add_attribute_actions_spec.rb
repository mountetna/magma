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
      attribute_group: attribute_group,
      read_only: true,
      restricted: false,
      unique: true,
      validation: {"type": "Regexp", "value": "^[a-z\\s]+$"}
    }
  end

  let(:action) { Magma::AddAttributeAction.new(project_name, action_params) }
  let(:model_name) { "labor" }
  let(:attribute_name) { "number_of_claws" }
  let(:attribute_group) { "info" }

  describe '#perform' do
    context "when it succeeds" do
      after do
        # Clear out new test attributes that are cached in memory
        Labors::Labor.attributes.delete(attribute_name.to_sym)
      end

      it 'adds a new attribute and returns no errors' do
        expect(action.perform).to eq(true)
        expect(action.errors).to be_empty
        expect(Labors::Labor.attributes[attribute_name.to_sym].display_name).to eq("name")
      end
    end

    context 'when it fails' do
      let(:project_name) { nil }

      it "captures the error and doesn't add the attribute" do
        expect(action.perform).to eq(false)
        expect(action.errors).not_to be_empty
        expect(Labors::Labor.attributes[attribute_name.to_sym]).to be_nil
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

    context "when the type is missing" do
      it 'captures a model error' do
        action = Magma::AddAttributeAction.new(project_name, action_params.except(:type))
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Type is invalid")
      end
    end

    context "when the type is an invalid type" do
      it 'captures a model error' do
        action = Magma::AddAttributeAction.new(project_name, action_params.merge(type: 'boot'))
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Type is invalid")
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
        expect(action.errors.first[:message]).to eq("attribute_name already exists on Labors::Labor")
      end
    end

    context "when attribute_name is not snake case" do
      let(:attribute_name) { 'firstName' }

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("attribute_name must be snake_case with no spaces")
      end
    end

    context "when attribute_name has spaces or leading numbers" do
      let(:attribute_name) { @attribute_name }

      it 'captures an attribute error' do
        [ "first\nname", ' first_name', 'first_name	' , '1x_attribute'].each do |name|
          @attribute_name = name
          expect(action.validate).to eq(false)
          expect(action.errors.first[:message]).to eq("attribute_name must be snake_case with no spaces")
        end
      end
    end

    context "when attribute_group contains multiple values" do
      let(:attribute_group) { attribute_groups.join(",")}
      let(:action_errors) { action.validate; action.errors.map { |v| v[:message] }.first }

      let(:attribute_groups) { ["a", "b", "c"] }
      it "works" do
        expect(action_errors).to be_nil
      end

      context "but one of the elements is non snake_case" do
        let(:attribute_groups) { ["a", "b-!A.A", "c"] }
        it "works" do
          expect(action_errors).to eql("attribute_group must be snake_case with no spaces")
        end
      end
    end

    context "when attribute_group is not a snake_case word" do
      let(:attribute_group) { @attribute_group }

      it 'captures an attribute error' do
        [ "infor\nmation", ' information', 'info_group	' , '1x_info'].each do |group|
          @attribute_group = group
          expect(action.validate).to eq(false)
          expect(action.errors.first[:message]).to eq("attribute_group must be snake_case with no spaces")
        end
      end
    end
    context "when adding a link attribute" do
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
        expect(action.errors.first[:message]).to eq("type cannot be a relation, use add_link instead.")
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
