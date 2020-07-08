describe Magma::AddModelAction do
  let(:action) { Magma::AddModelAction.new("labors", action_params) }

  describe "#perform" do
    context "for child/collection parent_link_type" do
      let(:action_params) do
        {
          action_name: "add_attribute",
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
      end
    end

    context "for table parent_link_type" do
      let(:action_params) do
        {
          action_name: "add_attribute",
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
      end
    end
  end
end
