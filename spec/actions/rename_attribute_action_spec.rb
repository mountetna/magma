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
end
