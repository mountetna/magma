describe Magma::AddModelAction do
  let(:action) { Magma::AddModelAction.new("labors", action_params) }

  describe "#perform" do
    context "for child/collection parent_link_type" do
      let(:action_params) do
        {
          action_name: "add_model",
          model_name: "new_child_model",
          identifier: "name",
          parent_model_name: "labor",
          parent_link_type: "child"
        }
      end

      after do
        # Remove test model and link relationships from memory
        project = Magma.instance.get_project(:labors)
        project.models.delete(:new_child_model)
        Labors.send(:remove_const, :NewChildModel)
        Labors::Labor.attributes.delete(:new_child_model)
      end

      it "adds the model and defines link relationships" do
        expect(action.perform).to eq(true)

        expect(
          Magma.instance.db[:models].
            where(project_name: "labors", model_name: "new_child_model")
        ).not_to be_nil

        expect { Labors::NewChildModel }.not_to raise_error(NameError)

        identifier = Labors::NewChildModel.attributes[:name]
        expect(identifier).to be_a(Magma::IdentifierAttribute)
        expect(identifier).not_to be_new

        parent = Labors::NewChildModel.attributes[:labor]
        expect(parent).to be_a(Magma::ParentAttribute)
        expect(parent).not_to be_new

        parent_link = Labors::Labor.attributes[:new_child_model]
        expect(parent_link).to be_a(Magma::ChildAttribute)
        expect(parent_link).not_to be_new

        expect(Labors::NewChildModel.is_date_shift_root?).to eq(false)
      end
    end

    context "for table parent_link_type" do
      let(:action_params) do
        {
          action_name: "add_model",
          model_name: "new_table_model",
          parent_model_name: "labor",
          parent_link_type: "table"
        }
      end

      after do
        # Remove test model and link relationships from memory
        project = Magma.instance.get_project(:labors)
        project.models.delete(:new_table_model)
        Labors.send(:remove_const, :NewTableModel)
        Labors::Labor.attributes.delete(:new_table_model)
      end

      it "adds the model and defines link relationships" do
        expect(action.perform).to eq(true)

        expect(
          Magma.instance.db[:models].
            where(project_name: "labors", model_name: "new_table_model")
        ).not_to be_nil

        expect { Labors::NewTableModel }.not_to raise_error(NameError)

        parent = Labors::NewTableModel.attributes[:labor]
        expect(parent).to be_a(Magma::ParentAttribute)
        expect(parent).not_to be_new

        parent_link = Labors::Labor.attributes[:new_table_model]
        expect(parent_link).to be_a(Magma::TableAttribute)
        expect(parent_link).not_to be_new

        model = Labors::NewTableModel
        expect(model.dictionary).to eq(nil)
      end

      it "accepts a dictionary when adding the model" do
        action_params[:dictionary] = {
          dictionary_model: "Labors::Labor",
          name: "name"
        }
        expect(action.perform).to eq(true)

        expect(
          Magma.instance.db[:models].
            where(project_name: "labors", model_name: "new_table_model")
        ).not_to be_nil

        expect { Labors::NewTableModel }.not_to raise_error(NameError)

        parent = Labors::NewTableModel.attributes[:labor]
        expect(parent).to be_a(Magma::ParentAttribute)
        expect(parent).not_to be_new

        parent_link = Labors::Labor.attributes[:new_table_model]
        expect(parent_link).to be_a(Magma::TableAttribute)
        expect(parent_link).not_to be_new

        model = Labors::NewTableModel
        expect(model.dictionary.to_hash).to eq({
          dictionary_model: "Labors::Labor",
          project_name: :labors,
          model_name: :labor,
          attributes: {name: :name}})

        # Remove the new dictionary from the database
        Magma.instance.db[:models].where(
          project_name: 'labors',
          model_name: 'new_table_model'
        ).update(dictionary: nil)
      end
    end
  end

  describe "#validate" do
    context "when a required field is missing" do
      let(:action_params) do
        {
          action_name: "add_model",
          identifier: "name",
          parent_model_name: "labor",
          parent_link_type: "child"
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("model_name is required")
      end
    end

    context "when a required field is not snake_case" do
      let(:action_params) do
        {
          action_name: "add_model",
          identifier: "name",
          model_name: "newChildModel",
          parent_model_name: "labor",
          parent_link_type: "child"
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("model_name must be snake_case")
      end
    end

    context "when the parent model doesn't exist" do
      let(:action_params) do
        {
          action_name: "add_model",
          model_name: "new_child_model",
          identifier: "name",
          parent_model_name: "houdini",
          parent_link_type: "child"
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("parent_model_name does not match a model")
      end
    end

    context "when parent_link_type is incorrect" do
      let(:action_params) do
        {
          action_name: "add_model",
          model_name: "new_child_model",
          identifier: "name",
          parent_model_name: "labor",
          parent_link_type: "grandchild"
        }
      end

      it "returns false and adds an error" do
        expect(action.validate).to eq(false)
        expect(action.errors.first[:message]).to eq("parent_link_type must be one of child, collection, table")
      end
    end

    context "when model_name is invalid" do
      let(:action_params) do
        {
          action_name: "add_model",
          model_name: "<template>",
          identifier: "name",
          parent_model_name: "labor",
          parent_link_type: "collection"
        }
      end

      it 'captures an error' do
        [ "my\nmodel", ' my_model', 'my_model	' , '1x_model', 'assay_2_study', 'looonnng___assay'].each do |name|
          action_params[:model_name] = name
          expect(action.validate).to eq(false)
          expect(action.errors.first[:message]).to eq("model_name must be snake_case and not contain numbers")
        end
      end
    end

    context "when a date_shift_root model already exists" do
      after do
        # Remove test model and link relationships from memory
        project = Magma.instance.get_project(:labors)
        project.models.delete(:new_child_model)
        Labors.send(:remove_const, :NewChildModel)
        Labors::Labor.attributes.delete(:new_child_model)
      end

      let(:action_params) do
        {
          action_name: "add_model",
          model_name: "new_child_model",
          identifier: "name",
          parent_model_name: "labor",
          parent_link_type: "child",
          date_shift_root: true
        }
      end

      let(:error_action_params) do
        {
          action_name: "add_model",
          model_name: "newer_child_model",
          identifier: "name",
          parent_model_name: "labor",
          parent_link_type: "child",
          date_shift_root: true
        }
      end

      let(:error_action) { Magma::AddModelAction.new("labors", error_action_params) }

      it "returns false and adds an error" do
        expect(action.perform).to eq(true)

        expect(error_action.validate).to eq(false)
        expect(error_action.errors.first[:message]).to eq("date_shift_root exists for project: new_child_model")
      end
    end
  end

  context "with date_shift_root param" do
    let(:action_params) do
      {
        action_name: "add_model",
        model_name: "new_child_model",
        identifier: "name",
        parent_model_name: "labor",
        parent_link_type: "child",
        date_shift_root: true
      }
    end

    after do
      # Remove test model and link relationships from memory
      project = Magma.instance.get_project(:labors)
      project.models.delete(:new_child_model)
      Labors.send(:remove_const, :NewChildModel)
      Labors::Labor.attributes.delete(:new_child_model)
    end

    it "adds the model and sets date_shift_root to true" do
      expect(action.perform).to eq(true)

      expect(
        Magma.instance.db[:models].
          where(project_name: "labors", model_name: "new_child_model")
      ).not_to be_nil

      expect { Labors::NewChildModel }.not_to raise_error(NameError)

      expect(Labors::NewChildModel.is_date_shift_root?).to eq(true)
    end
  end
end
