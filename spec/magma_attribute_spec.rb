require_relative '../lib/magma'
require 'yaml'

describe Magma::Attribute do
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
      attribute = Magma::Attribute.new("name", model, { desc: "Old name" })

      attribute.update_option(:desc, "New name")
      template = attribute.json_template

      expect(template[:desc]).to eq("New name")
    end
  end

  describe "#update_option" do
    it "updates editable options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { desc: "Old name" })

      attribute.update_option(:desc, "New name")

      expect(attribute.desc).to eq("New name")
    end

    it "doesn't update non-editable options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { match: "[A-z]" })

      attribute.update_option(:match, ".*")

      expect(attribute.match).to eq("[A-z]")
    end
  end
end
