describe Magma::SetDateShiftRootAction do
  let(:action) { Magma::SetDateShiftRootAction.new("labors", action_params) }

  describe "#perform" do
    let(:action_params) do
      {
        action_name: "set_date_shift_root",
        model_name: "new_child_model",
        date_shift_root: true,
      }
    end

    before do
      Magma::AddModelAction.new("labors", {
        action_name: "add_model",
        model_name: "new_child_model",
        identifier: "name",
        parent_model_name: "labor",
        parent_link_type: "child",
      }).perform
    end

    after do
      # Remove test model and link relationships from memory
      project = Magma.instance.get_project(:labors)
      project.models.delete(:new_child_model)
      Labors.send(:remove_const, :NewChildModel)
      Labors::Labor.attributes.delete(:new_child_model)
    end

    it "sets the date_shift_root flag" do
      expect(Labors::NewChildModel.is_date_shift_root?).to eq(false)

      expect(action.perform).to eq(true)

      expect(Labors::NewChildModel.is_date_shift_root?).to eq(true)
    end

    it "unsets the date_shift_root flag" do
      expect(action.perform).to eq(true)

      expect(Labors::NewChildModel.is_date_shift_root?).to eq(true)

      unset_action_params = {
        action_name: "set_date_shift_root",
        model_name: "new_child_model",
        date_shift_root: false,
      }

      unset_action = Magma::SetDateShiftRootAction.new("labors", unset_action_params)
      expect(unset_action.perform).to eq(true)

      expect(Labors::NewChildModel.is_date_shift_root?).to eq(false)
    end
  end

  describe "#validate" do
    context "when a required field is missing" do
      let(:action_params) do
        {
          action_name: "set_date_shift_root",
          model_name: "monster",
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq(
          "Must include :date_shift_root parameter"
        )
      end
    end

    context "when the model does not exist" do
      let(:action_params) do
        {
          action_name: "set_date_shift_root",
          model_name: "iliad",
          date_shift_root: true,
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
          action_name: "set_date_shift_root",
          model_name: "iliad",
          date_shift_root: true,
        }
      end

      it "returns false and adds an error" do
        # Wish there were a better way to test this...but because
        #   the specs use the yml project loader, all spec models
        #   are defined in the database.
        action.send("validate_db_model")
        expect(action.errors.first[:message]).to eq("Model is defined in code, not in the database.")
      end
    end

    context "when another model is already set as the date_shift_root" do
      let(:action_params) do
        {
          action_name: "set_date_shift_root",
          model_name: "monster",
          date_shift_root: true,
        }
      end

      before do
        Magma::AddModelAction.new("labors", {
          action_name: "add_model",
          model_name: "new_child_model",
          identifier: "name",
          parent_model_name: "labor",
          parent_link_type: "child",
          date_shift_root: true,
        }).perform
      end

      after do
        # Remove test model and link relationships from memory
        project = Magma.instance.get_project(:labors)
        project.models.delete(:new_child_model)
        Labors.send(:remove_const, :NewChildModel)
        Labors::Labor.attributes.delete(:new_child_model)
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("date_shift_root exists for project")
      end
    end
  end
end
