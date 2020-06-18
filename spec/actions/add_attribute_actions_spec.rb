describe Magma::AddAttributeAction do
  let(:project_name) { 'labors' }
  let(:action_params) do
    {
      project_name: project_name,
      action_name: "add_attribute",
      model_name: model_name,
      attribute_name: attribute_name,
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

  let(:add_attribute_action) { Magma::AddAttributeAction.new(project_name, action_params) }
  let(:model_name) { "monster" }
  let(:attribute_name) { "number_of_claws" }

  describe '#perform' do
    let(:params) { Magma::Attribute.creatable_options(action_params) }
    before do
      allow(Labors::Monster).to receive(:create_attribute)
    end

    it 'adds a new attribute and returns no errors' do
      expect(add_attribute_action.perform).to eq(true)
      expect(Labors::Monster).to have_received(:create_attribute).with(params).once
      expect(add_attribute_action.errors).to be_empty
    end

    describe 'when create fails' do
      before do
        allow(Labors::Monster).to receive(:create_attribute).and_raise('no creation')
      end

      it 'captures a creation error' do
        expect(add_attribute_action.perform).to eq(false)
        expect(Labors::Monster).to have_received(:create_attribute).with(params).once
        expect(add_attribute_action.errors).not_to be_empty
      end
    end
  end

  describe '#validate' do
    it 'is valid with an attribute and valid update keys' do
      expect(add_attribute_action.validate).to eq(true)
    end

    describe 'with no model' do
      let(:model_name) { 'super_duper' }

      it 'captures an model error' do
        expect(add_attribute_action.validate).to eq(false)
      end

      describe 'when creating an attribute that already exists' do
        let(:model_name) { 'monster' }
        let(:attribute_name) { 'name' }
        let(:errors) { add_attribute_action.errors }

        it 'captures an attribute error' do
          expect(add_attribute_action.validate).to eq(false)
          expect(errors.count).to eq(1)
          expect(errors.first[:message]).to eq('Attribute already exists')
        end
      end
    end

  end

  describe '#errors' do
    let(:errors) { [:boom] }

    before { allow(add_attribute_action).to receive(:errors).and_return(errors) }

    it 'returns an array of errors' do
      expect(add_attribute_action.errors).to eq(errors)
    end
  end
end



