describe Magma::RenameAttributeAction do
  let(:action) { Magma::RenameAttributeAction.new("labors", action_params) }

  describe "#perform" do
    let(:action_params) do
      {
        action: "rename_attribute",
        model_name: "monster",
        attribute_name: "species",
        new_attribute_name: "species_name"
      }
    end

    before do
      @original_attribute = Labors::Monster.attributes[:species].dup
    end

    after do
      # Rollback in memory changes to the attribute
      Labors::Monster.attributes.delete(:species_name)
      Labors::Monster.attributes[:species] = @original_attribute
    end

    it "renames the attribute" do
      expect(action.perform).to eq(true)

      expect(Labors::Monster.attributes[:species]).to be_nil

      renamed_attribute = Labors::Monster.attributes[:species_name]
      expect(renamed_attribute).not_to be_nil

      expect(renamed_attribute.attribute_name).to eq("species_name")
      expect(renamed_attribute.column_name).to eq(@original_attribute.column_name)
      expect(renamed_attribute.validation).to eq(@original_attribute.validation)
    end
  end

  describe "#validate" do
    context "when there's no attribute with attribute_name" do
      let(:action_params) do
        {
          action: "rename_attribute",
          model_name: "monster",
          attribute_name: "does_not_exist",
          new_attribute_name: "species_name"
        }
      end

      it "captures an attribute error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Attribute does not exist")
      end
    end

    context "when new_attribute_name is not properly formatted" do
      let(:action_params) do
        {
          action: "rename_attribute",
          model_name: "monster",
          attribute_name: "species",
          new_attribute_name: "speciesName"
        }
      end

      it "captures an attribute error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("attribute_name must be snake_case with no spaces")
      end
    end

    context "when the attribute is a link attribute" do
      before do
        @original_attribute = Labors::Monster.attributes[:victim].dup
      end

      after do
        # Rollback in memory changes to the attribute
        Labors::Monster.attributes.delete(:victor)
        Labors::Monster.attributes[:victim] = @original_attribute
      end

      let(:action_params) do
        {
          action: "rename_attribute",
          model_name: "monster",
          attribute_name: "victim",
          new_attribute_name: "victor"
        }
      end

      it "can rename to non-model name" do
        expect(Labors::Monster.attributes[:victim].link_model_name).to eq("victim")
        expect(Labors::Monster.attributes[:victor]).to eq(nil)
        expect(Labors::Victim.attributes[:monster].link_attribute_name).to eq("victim")
        expect(action.validate).to eq(true)
        expect(action.perform).to eq(true)
        expect(Labors::Monster.attributes[:victim]).to eq(nil)
        expect(Labors::Monster.attributes[:victor].link_model_name).to eq("victim")
        expect(Labors::Victim.attributes[:monster].link_attribute_name).to eq("victor")
      end
    end

    context "when there's already an attribute with new_attribute_name" do
      let(:action_params) do
        {
          action: "rename_attribute",
          model_name: "monster",
          attribute_name: "species",
          new_attribute_name: "victim"
        }
      end

      it "captures an attribute error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("attribute_name already exists on the model")
      end
    end
  end
end
