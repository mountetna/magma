describe Magma::AddDictionaryAction do
  let(:action) { Magma::AddDictionaryAction.new("labors", action_params) }

  describe "#perform" do
    let(:action_params) do
      {
        action_name: "add_dictionary",
        model_name: "new_child_model",
        dictionary: {
          dictionary_model: 'Labors::Codex',
          name: 'name'
        }
      }
    end

    before do
      Magma::AddModelAction.new("labors",         {
        action_name: "add_model",
        model_name: "new_child_model",
        identifier: "name",
        parent_model_name: "labor",
        parent_link_type: "child"
      }).perform
    end

    after do
      # Remove test model and link relationships from memory
      project = Magma.instance.get_project(:labors)
      project.models.delete(:new_child_model)
      Labors.send(:remove_const, :NewChildModel)
      Labors::Labor.attributes.delete(:new_child_model)
    end

    it "adds the dictionary to the model" do
      expect(Labors::NewChildModel.dictionary).to eq(nil)

      expect(action.perform).to eq(true)

      expect(Labors::NewChildModel.dictionary.to_hash).to eq({
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

    context "when the model does not exist in the database" do
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
        # Wish there were a better way to test this...but because
        #   the specs use the yml project loader, all spec models
        #   are defined in the database.
        action.send('validate_db_model')
        expect(action.errors.first[:message]).to eq("Model is defined in code, not in the database.")
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
