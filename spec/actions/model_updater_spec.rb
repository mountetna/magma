require 'magma/actions/model_update_actions'

describe Magma::ModelUpdateActions do
  let(:actions) do
    Magma::ModelUpdateActions.build(
      "labors", 
      [{
        action_name: action_name,
        model_name: "monster",
        attribute_name: "name",
        description: "The monster's name",
        display_name: "NAME"
      }]
    )
  end

  describe '#perform' do
    let(:action_name) { "update_attribute" }

    describe 'with invalid action_name' do
      let(:action_name) { "delete_everything" }

      it 'produces an error with invalid names' do
        expect(actions.perform).to eq(false)
        expect(actions.errors.size).to eq(1)
      end
    end

    describe 'with valid action_name' do
      let(:update_attribute_action) { double('update_attribute') }
      let(:validate_return) { true }
      let(:perform_return) { true }
      let(:action_errors) { [] }

      before do
        allow(Magma::UpdateAttributeAction).to receive(:new).and_return(update_attribute_action)
        allow(update_attribute_action).to receive(:validate).and_return(validate_return)
        allow(update_attribute_action).to receive(:perform).and_return(perform_return)
        allow(update_attribute_action).to receive(:errors).and_return(action_errors)
      end

      it 'calls validate and peform' do
        expect(actions.perform).to eq(true)
        expect(update_attribute_action).to have_received(:validate).once
        expect(update_attribute_action).to have_received(:perform).once
        expect(actions.errors).to eq([])
      end

      describe 'for add_attribute' do
        let(:action_name) { "add_attribute" }
        let(:add_attribute_action) { double('add_attribute') }

        before do
          allow(Magma::AddAttributeAction).to receive(:new).and_return(add_attribute_action)
          allow(add_attribute_action).to receive(:validate).and_return(validate_return)
          allow(add_attribute_action).to receive(:perform).and_return(perform_return)
          allow(add_attribute_action).to receive(:errors).and_return(action_errors)
        end

        it 'calls validate and perform' do
          expect(actions.perform).to eq(true) 
          expect(add_attribute_action).to have_received(:validate).once
          expect(add_attribute_action).to have_received(:perform).once
          expect(actions.errors).to eq([])
        end
      end

      describe 'when action#validate fails' do
        let(:validate_return) { false } 

        it 'perform fails and does not perform action' do
          expect(actions.perform).to eq(false)
          expect(update_attribute_action).to have_received(:validate).once
          expect(update_attribute_action).not_to have_received(:perform)
        end
      end

      describe 'when action#perform fails' do
        let(:perform_return) { false }

        it 'perform is called on action' do
          expect(actions.perform).to eq(false)
          expect(update_attribute_action).to have_received(:validate).once
          expect(update_attribute_action).to have_received(:perform).once
        end
      end

      describe '#errors' do
        let(:action_errors) { [:oops] }

        it 'returns action#errors' do
          expect(actions.errors).to eq(action_errors)
        end
      end
    end 
  end
end
