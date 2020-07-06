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

    context "when actions generate migrations" do
      let(:actions) do
        Magma::ModelUpdateActions.build(
          "labors",
          [
            {
              action_name: "add_attribute",
              model_name: "monster",
              attribute_name: "attribute_one",
              type: "string"
            },
            {
              action_name: "add_attribute",
              model_name: "prize",
              attribute_name: "attribute_two",
              type: "string"
            }
          ]
        )
      end

      after do
        # Clear out new test attributes that are cached in memory
        Labors::Monster.attributes.delete(:attribute_one)
        Labors::Prize.attributes.delete(:attribute_two)
      end

      it "runs migrations to update the database" do
        actions.perform
        expect(Labors::Monster.dataset.columns!).to include(:attribute_one)
        expect(Labors::Prize.dataset.columns!).to include(:attribute_two)
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
