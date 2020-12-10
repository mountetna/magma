describe Magma::AddDictionaryAction do
  let(:action) { Magma::AddDictionaryAction.new("labors", action_params) }

  describe "#perform" do
    let(:action_params) do
      {
        action_name: "add_dictionary",
        model_name: "monster",
        dictionary: {
          dictionary_model: 'Labors::Codex',
          name: 'name'
        }
      }
    end

    after do
      # Remove the new dictionary from memory
      model = Magma.instance.db[:models].where(
        project_name: 'labors',
        model_name: 'monster'
      ).first
      model.update(dictionary: nil)
    end

    it "adds the dictionary to the model" do
      model = Labors::Monster
      expect(model.dictionary).to eq(nil)

      expect(action.perform).to eq(true)

      model = Labors::Monster
      expect(model.dictionary.to_hash).to eq({
        dictionary_model: "Labors::Codex",
        project_name: :labors,
        model_name: :codex,
        attributes: {name: :name}})
    end
  end

  describe "#validate" do
    context "when a required field is missing" do
      let(:action_params) do
        {
          action_name: "add_dictionary",
          model_name: "monster",
          dictionary: {
            name: 'name'
          }
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq(
          "Must include :dictionary_model in :dictionary.")
      end
    end

    context "when the model does not exist" do
      let(:action_params) do
        {
          action_name: "add_dictionary",
          model_name: "iliad",
          dictionary: {
            dictionary_model: 'Labors::Codex',
            name: 'name'
          }
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Model does not exist.")
      end
    end

    context "when the dictionary_model doesn't exist" do
      let(:action_params) do
        {
          action_name: "add_dictionary",
          model_name: "monster",
          dictionary: {
            dictionary_model: 'Labors::Iliad',
            name: 'name'
          }
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("Dictionary model does not exist.")
      end
    end

    context "when a model attribute does not exist" do
      let(:action_params) do
        {
          action_name: "add_dictionary",
          model_name: "monster",
          dictionary: {
            dictionary_model: 'Labors::Codex',
            age: 'name'
          }
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq(
          "attribute_name \"age\" does not exist on \"Labors::Monster\".")
      end
    end

    context "when a dictionary_model attribute does not exist" do
      let(:action_params) do
        {
          action_name: "add_dictionary",
          model_name: "monster",
          dictionary: {
            dictionary_model: 'Labors::Codex',
            name: 'print_edition'
          }
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq(
          "attribute_name \"print_edition\" does not exist on dictionary \"Labors::Codex\".")
      end
    end
  end
end
