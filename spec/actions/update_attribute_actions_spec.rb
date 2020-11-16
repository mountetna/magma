describe Magma::UpdateAttributeAction do
  let(:action) { Magma::UpdateAttributeAction.new("labors", action_params) }

  describe '#perform' do
    let(:action_params) do
      {
        action_name: "update_attribute",
        model_name: "monster",
        attribute_name: "name",
        description: "The monster's name",
        display_name: "NAME"
      }
    end

    before do
      @original_attribute = Labors::Monster.attributes[:name].dup
    end

    after do
      # Rollback in memory changes to the attribute
      attribute = Labors::Monster.attributes[:name]
      attribute.description = @original_attribute.description
      attribute.display_name = @original_attribute.display_name
    end

    it 'updates the attribute' do
      expect(action.perform).to eq(true)

      expect(Labors::Monster.attributes[:name].description).to eq("The monster's name")
      expect(Labors::Monster.attributes[:name].display_name).to eq("NAME")
    end
  end

  describe '#validate' do
    context "when there's not attribute with attribute_name" do
      let(:action_params) do
        {
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: "not_an_attribute",
          description: "The monster's name",
          display_name: "NAME"
        }
      end

      it 'captures an attribute error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Attribute does not exist")
      end
    end

    context "when fields are not valid attribute options" do
      let(:action_params) do
        {
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: "name",
          age: 132
        }
      end

      it 'captures an attribute option error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Attribute does not implement age")
      end
    end

    context "when updating the restricted value of an attribute" do
      let(:attribute_name) { "name" }
      let(:action_params) do
        {
            action_name: "update_attribute",
            model_name: "victim",
            attribute_name: attribute_name,
            restricted: true
        }
      end

      it "succeeds" do
        expect(action.validate).to eq(true)
      end

      context "and the attribute_name is restricted" do
        let(:attribute_name) { "restricted" }

        it "false" do
          expect(action.validate).to eq(false)
          expect(action.errors.last[:message]).to eq("restricted column may not, itself, be restricted")
        end
      end
    end

    context "when fields are restricted options" do
      let(:action_params) do
        {
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: "name",
          name: "new_name"
        }
      end

      it 'captures an attribute option error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("name cannot be changed")
      end
    end

    context "when fields are invalid for the options data type" do
      let(:action_params) do
        {
          action_name: "update_attribute",
          model_name: "monster",
          attribute_name: "name",
          validation: 23
        }
      end

      it 'captures an attribute option error' do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("validation is not properly formatted")
      end
    end
  end
end
