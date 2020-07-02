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

    it "reports attribute_class as 'Magma::ForeignKeyAttribute' for Magma::LinkAttributes" do
      attribute = Labors::Monster.attributes[:reference_monster]
      template = attribute.json_template

      expect(template[:attribute_class]).to eq("Magma::ForeignKeyAttribute")
    end

    it "includes validation arrays as options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("fruits", model, {
        validation: { type: "Array", value: ["apple", "banana"] }
      })
      template = attribute.json_template

      expect(template[:options]).to eq(["apple", "banana"])
    end

    it "includes validation regexes as match" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("fruits", model, {
        validation: { type: "Regexp", value: /.*/ }
      })
      template = attribute.json_template

      expect(template[:match]).to eq(".*")
    end
  end

  describe "#revision_to_loader" do
    it "returns entry for editable string backed options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { description: "Old name" })

      entry = attribute.revision_to_loader(:description, "New name")

      expect(entry).to eq(["name", "New name"])
    end

    it "returns entry for editable JSON backed options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {
        validation: { type: "Array", value: [1, 2, 3] }
      })

      # Call attribute#validation_object to verify the cached validation_object
      # gets reset
      attribute.validation_object

      entry = attribute.revision_to_loader(:validation, { type: "Array", value: [4, 5, 6] })

      expect(entry[0]).to eq("name")
      expect(entry[1].to_json).to eq({type: "Array", value: [4, 5, 6]}.to_json)
    end
  end

  describe "#revision_to_payload" do
    it "returns entry for editable string backed options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { description: "Old name" })

      entry = attribute.revision_to_payload(
        :description,
        "New name",
        Etna::User.new({
          email: "outis@mountolympus.org"
        }))

      expect(entry).to eq(["name", "New name"])
    end

    it "returns entry for editable JSON backed options" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {
        validation: { type: "Array", value: [1, 2, 3] }
      })

      # Call attribute#validation_object to verify the cached validation_object
      # gets reset
      attribute.validation_object

      entry = attribute.revision_to_payload(
        :validation,
        { type: "Array", value: [4, 5, 6] },
        Etna::User.new({
          email: "outis@mountolympus.org"
        }))

      expect(entry[0]).to eq("name")
      expect(entry[1].to_json).to eq({type: "Array", value: [4, 5, 6]}.to_json)
    end
  end

  describe "#query_to_payload" do
    it "returns attribute value for a JSON payload" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, { description: "Old name" })

      query = attribute.query_to_payload("New name")

      expect(query).to eq("New name")
    end
  end

  describe "#query_to_tsv" do
  it "returns attribute value for a TSV payload" do
    model = double("model", project_name: :project, model_name: :model)
    attribute = Magma::Attribute.new("name", model, { description: "Old name" })

    query = attribute.query_to_tsv("New name")

    expect(query).to eq("New name")
  end
end

  describe "#validation_object" do
    it "builds ArrayValidationObjects using validation options from the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        type: "string",
        created_at: Time.now,
        updated_at: Time.now,
        validation: Sequel.pg_json_wrap(
          { type: "Array", value: ["a", "b", "c"] }
        )
      )

      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {})

      expect(attribute.validation_object.validate("a")).to eq(true)
    end

    it "builds ArrayValidationObjects using validation options defined on the attribute" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {
        validation: { type: "Array", value: ["a", "b", "c"] }
      })

      expect(attribute.validation_object.validate("a")).to eq(true)
    end

    it "builds RangeValidationObjects using validation options from the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        type: "integer",
        created_at: Time.now,
        updated_at: Time.now,
        validation: Sequel.pg_json_wrap(
          { type: "Range", begin: 1, end: 10 }
        )
      )

      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {})

      expect(attribute.validation_object.validate(5)).to eq(true)
    end

    it "builds RangeValidationObjects using validation options defined on the attribute" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {
        validation: { type: "Range", begin: 1, end: 10 }
      })

      expect(attribute.validation_object.validate(5)).to eq(true)
    end

    it "builds RegexpValidationObjects using validation options from the database" do
      Magma.instance.db[:attributes].insert(
        project_name: "project",
        model_name: "model",
        attribute_name: "name",
        type: "string",
        created_at: Time.now,
        updated_at: Time.now,
        validation: Sequel.pg_json_wrap(
          { type: "Regexp", value: "^[a-zA-Z]{1}$" }
        )
      )

      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {})

      expect(attribute.validation_object.validate("A")).to eq(true)
    end

    it "builds RegexpValidationObjects using validation options defined on the attribute" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {
        validation: { type: "Regexp", value: /^[a-zA-Z]{1}$/ }
      })

      expect(attribute.validation_object.validate("A")).to eq(true)
    end

    it "contains a ValidationOjbect" do
      model = double("model", project_name: :project, model_name: :model)
      attribute = Magma::Attribute.new("name", model, {
        validation: { type: "Regexp", value: /^[a-zA-Z]{1}$/ }
      })
      json_validation_object = attribute.json_template[:validation]

      expect(json_validation_object.to_json).to eq("{\"type\":\"Regexp\",\"value\":\"(?-mix:^[a-zA-Z]{1}$)\"}")
    end
  end
end
