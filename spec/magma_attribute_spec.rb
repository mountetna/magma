require_relative '../lib/magma'
require 'yaml'

describe Magma::Attribute do
  describe "#json_template" do
    it "includes attribute defaults" do
      attribute = Magma::Attribute.new(
        attribute_name: "name",
        format_hint: "Hint"
      )

      template = attribute.json_template

      expect(template[:display_name]).to eq("Name")
      expect(template[:format_hint]).to eq("Hint")
    end

    it "includes updated attributes" do
      attribute = Magma::StringAttribute.new(
        project_name: "projects",
        model_name: "model",
        attribute_name: "name",
        description: "Old name"
      )

      attribute.update(description: "New name")
      template = attribute.json_template

      expect(template[:desc]).to eq("New name")
    end

    it "continues reporting attribute_class as 'Magma::Attribute' for old Magma::Attributes" do
      attribute = Magma::BooleanAttribute.new(attribute_name: "name")
      template = attribute.json_template

      expect(template[:attribute_class]).to eq("Magma::Attribute")
    end

    it "continues reporting attribute_class as 'Magma::ForeignKeyAttribute' for old Magma::ForeignKeyAttributes" do
      attribute = Labors::Monster.attributes[:labor]
      template = attribute.json_template

      expect(template[:attribute_class]).to eq("Magma::ForeignKeyAttribute")
    end

    it "includes validation arrays as options" do
      attribute = Magma::Attribute.new(
        attribute_name: "fruits",
        validation: { type: "Array", value: ["apple", "banana"] }
      )

      template = attribute.json_template

      expect(template[:options]).to eq(["apple", "banana"])
    end

    it "includes validation regexes as match" do
      attribute = Magma::Attribute.new(
        attribute_name: "fruits",
        validation: { type: "Regexp", value: /.*/ }
      )

      template = attribute.json_template

      expect(template[:match]).to eq(".*")
    end

    it "contains a ValidationOjbect" do
      attribute = Magma::Attribute.new(
        attribute_name: "name",
        validation: { type: "Regexp", value: /^[a-zA-Z]{1}$/ }
      )

      json_validation_object = attribute.json_template[:validation]

      expect(json_validation_object.to_json).to eq("{\"type\":\"Regexp\",\"value\":\"(?-mix:^[a-zA-Z]{1}$)\"}")
    end
  end

  describe "#update_option" do
    it "updates editable string backed options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { description: "Old name" })

      attribute.update_option(:description, "New name")

      expect(attribute.description).to eq("New name")
    end

    it "updates editable JSON backed options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {
        validation: { type: "Array", value: [1, 2, 3] }
      })

      # Call attribute#validation_object to verify the cached validation_object
      # gets reset
      attribute.validation_object

      attribute.update_option(:validation, { type: "Array", value: [4, 5, 6] })

      expect(attribute.validation_object.options).to eq([4, 5, 6])
    end

    it "doesn't update non-editable options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {})

      attribute.update_option(:loader, "foo")

      expect(attribute.loader).to be_nil
    end
  end

  describe "#validation_object" do
    it "builds ArrayValidationObjects using validation options from the database" do
      attribute = Magma::StringAttribute.create(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        validation: { type: "Array", value: ["a", "b", "c"] }
      )

      expect(attribute.validation_object.validate("a")).to eq(true)
    end

    it "builds ArrayValidationObjects using validation options defined on the attribute" do
      attribute = Magma::Attribute.new(
        attribute_name: "name",
        validation: { type: "Array", value: ["a", "b", "c"] }
      )

      expect(attribute.validation_object.validate("a")).to eq(true)
    end

    it "builds RangeValidationObjects using validation options from the database" do
      attribute = Magma::IntegerAttribute.create(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        validation: { type: "Range", begin: 1, end: 10 }
      )

      expect(attribute.validation_object.validate(5)).to eq(true)
    end

    it "builds RangeValidationObjects using validation options defined on the attribute" do
      attribute = Magma::Attribute.new(
        attribute_name: "name",
        validation: { type: "Range", begin: 1, end: 10 }
      )

      expect(attribute.validation_object.validate(5)).to eq(true)
    end

    it "builds RegexpValidationObjects using validation options from the database" do
      attribute = Magma::StringAttribute.create(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        validation: { type: "Regexp", value: "^[a-zA-Z]{1}$" }
      )

      expect(attribute.validation_object.validate("A")).to eq(true)
    end

    it "builds RegexpValidationObjects using validation options defined on the attribute" do
      attribute = Magma::Attribute.new(
        attribute_name: "name",
        validation: { type: "Regexp", value: /^[a-zA-Z]{1}$/ }
      )

      expect(attribute.validation_object.validate("A")).to eq(true)
    end
  end
end
