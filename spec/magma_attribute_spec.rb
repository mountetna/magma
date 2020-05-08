require_relative '../lib/magma'
require 'yaml'

describe Magma::Attribute do
  describe "#initialize" do
    it "sets options that only exist in the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        created_at: Time.now,
        updated_at: Time.now,
        format_hint: "First M Last"
      )

      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {})

      expect(attribute.format_hint).to eq("First M Last")
    end

    it "sets options that only exist on the attribute" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { format_hint: "Last, First M" })

      expect(attribute.format_hint).to eq("Last, First M")
    end

    it "defers to options defined in the database when setting options" do
      Magma.instance.db[:attributes].insert(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        created_at: Time.now,
        updated_at: Time.now,
        format_hint: "First M Last"
      )

      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { format_hint: "Last, First M" })

      expect(attribute.format_hint).to eq("First M Last")
    end
  end

  describe "#json_template" do
    it "includes attribute defaults" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { format_hint: "Hint" })
      template = attribute.json_template

      expect(template[:display_name]).to eq("Name")
      expect(template[:format_hint]).to eq("Hint")
    end

    it "includes attributes saved in the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        created_at: Time.now,
        updated_at: Time.now,
        display_name: "Something original",
        format_hint: "A better hint!"
      )

      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { format_hint: "Hint" })
      template = attribute.json_template

      expect(template[:display_name]).to eq("Something original")
      expect(template[:format_hint]).to eq("A better hint!")
    end

    it "includes updated attributes" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { description: "Old name" })

      attribute.update_option(:description, "New name")
      template = attribute.json_template

      expect(template[:desc]).to eq("New name")
    end

    it "uses desc as a fallback for description" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { desc: "Old name" })
      template = attribute.json_template

      expect(template[:desc]).to eq("Old name")
    end

    it "continues reporting attribute_class as 'Magma::Attribute' for old Magma::Attributes" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::BooleanAttribute.new("name", model, {})
      template = attribute.json_template

      expect(template[:attribute_class]).to eq("Magma::Attribute")
    end

    it "continues reporting attribute_class as 'Magma::ForeignKeyAttribute' for old Magma::ForeignKeyAttributes" do
      attribute = Labors::Monster.attributes[:labor]
      template = attribute.json_template

      expect(template[:attribute_class]).to eq("Magma::ForeignKeyAttribute")
    end
  end

  describe "#update_option" do
    it "updates editable options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { description: "Old name" })

      attribute.update_option(:description, "New name")

      expect(attribute.description).to eq("New name")
    end

    it "doesn't update non-editable options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { match: "[A-z]" })

      attribute.update_option(:match, ".*")

      expect(attribute.match).to eq("[A-z]")
    end
  end
end
