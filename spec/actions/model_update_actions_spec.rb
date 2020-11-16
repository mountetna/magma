describe Magma::ModelUpdateActions do
  describe '#perform' do
    context 'with invalid action_name' do
      let(:actions) do
        Magma::ModelUpdateActions.build(
          "labors",
          [{
            action_name: "delete_everything",
            model_name: "monster",
            attribute_name: "name",
            description: "The monster's name"
          }]
        )
      end

      it 'produces an error with invalid names' do
        expect(actions.perform).to eq(false)
        expect(actions.errors.first[:message]).to eq("Invalid action type")
      end
    end

    context "with valid actions" do
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
              type: "integer"
            }
          ]
        )
      end

      after do
        # Clear out new test attributes that are cached in memory
        Labors::Monster.attributes.delete(:attribute_one)
        Labors::Prize.attributes.delete(:attribute_two)
      end

      it "persists action changes in both the db and in memory" do
        expect(actions.perform).to eq(true)

        expect(Labors::Monster.dataset.columns!).to include(:attribute_one)
        expect(Labors::Monster.attributes[:attribute_one]).to be_a(Magma::StringAttribute)

        expect(Labors::Prize.dataset.columns!).to include(:attribute_two)
        expect(Labors::Prize.attributes[:attribute_two]).to be_a(Magma::IntegerAttribute)
      end
    end

    context "when an action fails" do
      let(:actions) do
        Magma::ModelUpdateActions.build(
          "labors",
          [
            {
              action_name: "add_attribute",
              model_name: "monster",
              attribute_name: "new_attribute",
              type: "string"
            },
            {
              action_name: "update_attribute",
              model_name: "monster",
              attribute_name: "species",
              validation: "invalid"
            }
          ]
        )
      end

      it "returns false and doesn't persist any action changes" do
        expect(actions.perform).to eq(false)
        expect(actions.errors).not_to be_empty

        expect(Magma::Attribute["labors", "monster", "new_attribute"]).to be_nil
        expect(Labors::Monster.dataset.columns!).not_to include(:new_attribute)
        expect(Labors::Monster.attributes.keys).not_to include(:new_attribute)
        expect(Labors::Monster.attributes[:species].validation).not_to eq("validation")
      end
    end
  end
end
