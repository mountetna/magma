require_relative '../lib/magma'
require 'yaml'

describe Magma::Attribute do
  describe "#json_template" do
    it "includes attribute defaults" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {})
      template = attribute.json_template

      expect(template[:display_name]).to eq("Name")
    end

    it "includes attributes saved in the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        created_at: Time.now,
        updated_at: Time.now,
        display_name: "Something original"
      )

      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {})
      template = attribute.json_template

      expect(template[:display_name]).to eq("Something original")
    end
  end
end
