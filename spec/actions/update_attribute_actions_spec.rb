describe Magma::UpdateAttributeAction do
  let(:project_name) { 'labors' }
  let(:action_params) do 
    {
      action_name: "update_attribute",
      model_name: "monster",
      attribute_name: "name",
      description: value,
      display_name: "NAME"
    } 
  end
  
  let(:update_attribute_action) { Magma::UpdateAttributeAction.new(project_name, action_params) }
  let(:value) { "The monster's name" }

  describe '#perform' do
    let(:attribute) { Labors::Monster.attributes[:name] }

    before do
      allow(attribute).to receive(:update)
    end

    it 'updates the option and returns no errors' do
      expect(update_attribute_action.perform).to eq(true)
      expect(attribute).to have_received(:update).once
      expect(update_attribute_action.errors).to be_empty
    end

    describe 'when update fails' do
      before do
        allow(attribute).to receive(:update).and_raise(Sequel::ValidationFailed)
      end

      it 'captures an update error' do
        expect(update_attribute_action.perform).to eq(false)
        expect(attribute).to have_received(:update).once
        expect(update_attribute_action.errors).not_to be_empty
      end
    end
  end

  describe '#validate' do
    it 'is valid with an attribute and valid update keys' do
      expect(update_attribute_action.validate).to eq(true)
    end

    describe 'with no attribute' do
      before { action_params.merge!(attribute_name: 'not_an_attribute') }

      let(:errors) { update_attribute_action.errors }

      it 'captures an attribute error' do
        expect(update_attribute_action.validate).to eq(false)  
        expect(errors.count).to eq(1)
        expect(errors.first[:message]).to eq("Attribute does not exist")
      end
    end

    describe 'when updating a non-existent field' do
      before { action_params.merge!(age: 132) }

      let(:errors) { update_attribute_action.errors }

      it 'captures an attribute option error' do
        expect(update_attribute_action.validate).to eq(false)
        expect(errors.count).to eq(1)
        expect(errors.first[:message]).to eq("Attribute does not implement age")
      end
    end
  end

  describe '#errors' do
    let(:errors) { [:oops] }

    before { allow(update_attribute_action).to receive(:errors).and_return(errors) }

    it 'returns an array of errors' do
      expect(update_attribute_action.errors).to eq(errors)
    end
  end

end
